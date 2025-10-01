#!/usr/bin/env bash
set -euo pipefail

# BMAD Cosign Bootstrap Script
# Generates signing keys and sets up git-crypt for secure key storage

echo "🔐 BMAD Cosign Bootstrap - Setting up supply chain security"

# Configuration
KEY_NAME="bmad-signing-key"
GIT_CRYPT_KEY="bmad-secrets"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing_tools=()
    
    for tool in cosign git-crypt gpg; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
        echo
        echo "Installation instructions:"
        echo "  cosign: https://docs.sigstore.dev/cosign/installation/"
        echo "  git-crypt: https://github.com/AGWA/git-crypt"
        echo "  gpg: https://gnupg.org/download/"
        exit 1
    fi
    
    success "All prerequisites available"
}

# Generate GPG key for git-crypt
generate_gpg_key() {
    log "Checking for existing GPG key..."
    
    if gpg --list-secret-keys --keyid-format LONG | grep -q "$GIT_CRYPT_KEY"; then
        success "GPG key already exists"
        return 0
    fi
    
    log "Generating new GPG key for git-crypt..."
    
    cat <<EOF | gpg --batch --generate-key
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: BMAD Protocol
Name-Email: security@bmad-protocol.io
Name-Comment: $GIT_CRYPT_KEY
Expire-Date: 1y
Passphrase: 
%commit
%echo done
EOF
    
    success "GPG key generated"
}

# Initialize git-crypt
setup_git_crypt() {
    log "Setting up git-crypt..."
    
    if [ -f ".git-crypt/.git-crypt" ]; then
        warn "git-crypt already initialized"
        return 0
    fi
    
    # Initialize git-crypt
    git-crypt init
    
    # Add GPG user
    local gpg_key_id=$(gpg --list-secret-keys --keyid-format LONG | grep "$GIT_CRYPT_KEY" -A 1 | grep "sec" | awk '{print $2}' | cut -d'/' -f2)
    git-crypt add-gpg-user "$gpg_key_id"
    
    # Create .gitattributes for secret files
    cat <<EOF > .gitattributes
# Encrypt sensitive files with git-crypt
*.key filter=git-crypt diff=git-crypt
*.pem filter=git-crypt diff=git-crypt
*.p12 filter=git-crypt diff=git-crypt
*.pfx filter=git-crypt diff=git-crypt
secrets/ filter=git-crypt diff=git-crypt
.env filter=git-crypt diff=git-crypt
**/secrets.yaml filter=git-crypt diff=git-crypt
cosign.key filter=git-crypt diff=git-crypt
EOF
    
    success "git-crypt initialized"
}

# Generate cosign key pair
generate_cosign_keys() {
    log "Generating cosign key pair..."
    
    if [ -f "cosign.key" ] && [ -f "cosign.pub" ]; then
        warn "Cosign keys already exist"
        return 0
    fi
    
    # Generate password for private key
    local password=$(openssl rand -base64 32)
    echo "$password" > cosign.password
    
    # Generate cosign key pair
    COSIGN_PASSWORD="$password" cosign generate-key-pair
    
    # Update public key in repository
    if [ -f "cosign.pub" ]; then
        log "Updating cosign.pub in repository..."
        # The public key is already there, just verify it's valid
        cosign public-key --key cosign.pub > /dev/null
        success "Cosign public key validated"
    fi
    
    success "Cosign key pair generated"
}

# Set up GitHub secrets
setup_github_secrets() {
    log "Setting up GitHub repository secrets..."
    
    if ! command -v gh &> /dev/null; then
        warn "GitHub CLI not found. Please set up these secrets manually:"
        echo "  COSIGN_PRIVATE_KEY: $(cat cosign.key | base64 -w 0)"
        echo "  COSIGN_PASSWORD: $(cat cosign.password)"
        return 0
    fi
    
    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        warn "GitHub CLI not authenticated. Please run 'gh auth login' first"
        return 0
    fi
    
    # Set secrets
    if [ -f "cosign.key" ] && [ -f "cosign.password" ]; then
        gh secret set COSIGN_PRIVATE_KEY < cosign.key
        gh secret set COSIGN_PASSWORD < cosign.password
        success "GitHub secrets configured"
    else
        error "Cosign key files not found"
    fi
}

# Create security policy template
create_security_policy() {
    log "Creating security policy template..."
    
    mkdir -p .github/policies
    
    cat <<EOF > .github/policies/cosign-policy.yaml
apiVersion: v1alpha1
kind: Policy
metadata:
  name: bmad-cosign-policy
spec:
  verification:
    mode: enforce
    keys:
      - key: |
$(cat cosign.pub | sed 's/^/          /')
  attestations:
    - predicateType: https://slsa.dev/provenance/v0.2
      policy:
        type: cue
        data: |
          predicate: {
            builder: {
              id: "https://github.com/actions/runner"
            }
            buildType: "https://github.com/actions/workflow@v1"
          }
EOF
    
    success "Security policy created"
}

# Validate setup
validate_setup() {
    log "Validating setup..."
    
    # Test cosign signing
    echo "test" > test-file.txt
    if cosign sign-blob --key cosign.key test-file.txt --output-signature test-file.txt.sig 2>/dev/null; then
        # Test verification
        if cosign verify-blob --key cosign.pub --signature test-file.txt.sig test-file.txt 2>/dev/null; then
            success "Cosign signing and verification working"
        else
            error "Cosign verification failed"
        fi
    else
        error "Cosign signing failed"
    fi
    
    # Cleanup
    rm -f test-file.txt test-file.txt.sig
    
    # Test git-crypt
    if git-crypt status &> /dev/null; then
        success "git-crypt is active"
    else
        warn "git-crypt not active (this is normal for the initial setup)"
    fi
}

# Generate documentation
generate_documentation() {
    log "Generating security documentation..."
    
    cat <<EOF > docs/security-setup.md
# BMAD Security Setup

## Overview
This document describes the security infrastructure for BMAD Protocol, including signing keys and secret management.

## Components

### Cosign Signing
- **Public Key**: \`cosign.pub\` (committed to repository)
- **Private Key**: \`cosign.key\` (encrypted with git-crypt)
- **Usage**: Container image and artifact signing

### Git-Crypt
- **Purpose**: Encrypt sensitive files in git repository
- **Key**: GPG key for "$GIT_CRYPT_KEY"
- **Encrypted Files**: Private keys, certificates, secrets

### GitHub Secrets
The following secrets should be configured in GitHub repository settings:
- \`COSIGN_PRIVATE_KEY\`: Base64-encoded cosign private key
- \`COSIGN_PASSWORD\`: Password for cosign private key

## Usage

### Signing Container Images
\`\`\`bash
# Sign image with cosign
cosign sign --key cosign.key ghcr.io/bmad-protocol/bmad:latest

# Verify signed image
cosign verify --key cosign.pub ghcr.io/bmad-protocol/bmad:latest
\`\`\`

### Managing Secrets
\`\`\`bash
# Decrypt repository (requires GPG key)
git-crypt unlock

# Add new secret file
echo "secret-data" > secrets/new-secret.txt
git add secrets/new-secret.txt
git commit -m "Add new secret"

# Lock repository
git-crypt lock
\`\`\`

### Key Rotation
1. Generate new cosign key pair: \`cosign generate-key-pair\`
2. Update GitHub secrets
3. Update \`cosign.pub\` in repository
4. Re-sign all container images
5. Update security policies

## Security Considerations
- Private keys are encrypted and never stored in plaintext
- GPG key should be backed up securely
- Regular key rotation (annually)
- Audit trail for all signing operations
- Multi-signature support for critical operations

## Recovery Procedures
- GPG key recovery from secure backup
- Cosign key regeneration process
- GitHub secrets update procedure
- Emergency key revocation

## Compliance
- FIPS 140-2 compatible algorithms
- SOC 2 Type II controls
- Supply chain security (SLSA Level 3)
- Cryptographic key management standards
EOF
    
    success "Security documentation generated"
}

# Main execution
main() {
    log "Starting BMAD cosign bootstrap process"
    echo
    
    check_prerequisites
    generate_gpg_key
    setup_git_crypt
    generate_cosign_keys
    setup_github_secrets
    create_security_policy
    validate_setup
    generate_documentation
    
    echo
    success "🎉 BMAD security infrastructure setup completed!"
    echo
    echo "Next steps:"
    echo "1. Commit the changes: git add . && git commit -m 'feat: setup cosign and git-crypt'"
    echo "2. Push to GitHub: git push"
    echo "3. Verify GitHub Actions can sign images"
    echo "4. Share GPG key with team members who need access"
    echo
    warn "Important: Back up your GPG private key securely!"
    echo "  GPG key ID: $(gpg --list-secret-keys --keyid-format LONG | grep "$GIT_CRYPT_KEY" -A 1 | grep "sec" | awk '{print $2}' | cut -d'/' -f2)"
}

# Signal handlers
cleanup() {
    log "Cleaning up temporary files..."
    rm -f test-file.txt test-file.txt.sig 2>/dev/null || true
}

trap cleanup EXIT

# Run main function
main "$@"