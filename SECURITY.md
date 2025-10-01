# Security Policy

## Reporting Vulnerabilities

Please email security@bmad-protocol.io (PGP: 0xBMAD1234) for security issues.

We follow [RFC 9116](https://tools.ietf.org/rfc/rfc9116.txt) and aim for:
- **24-hour acknowledgment**
- **7-day fix window** for critical issues
- **30-day disclosure timeline**

## Security Measures

BMAD Protocol implements defense-in-depth:

### Supply Chain Security
- All container images signed with Cosign
- SLSA Level 3 provenance generation
- Dependency vulnerability scanning with Trivy
- Pin all dependencies with cryptographic hashes

### Runtime Security
- Firecracker micro-VM isolation for all workloads
- eBPF syscall filtering and allow-lists
- SPIFFE/SPIRE for workload identity (15-minute cert rotation)
- Read-only root filesystems

### Policy Enforcement
- Open Policy Agent (OPA) for security policies
- Mandatory cost and security guardrails
- SMT solver verification for critical operations
- Continuous compliance monitoring

### Audit & Compliance
- Merkle-rooted audit logs (7-year retention)
- Full execution replay capability
- SOC 2, CIS, GDPR evidence auto-generation
- Tamper-evident logging

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | ✅                |
| 0.1.x   | ✅                |

## Known Security Considerations

1. **API Keys**: Store in Kubernetes secrets, never in code
2. **Firecracker**: Requires privileged container for VM management
3. **Network Policies**: Default deny-all with explicit allow-lists
4. **Image Scanning**: All images scanned for CVEs before deployment

## Security Contacts

- Primary: security@bmad-protocol.io
- Emergency: security-emergency@bmad-protocol.io
- PGP Key: [Download](https://bmad-protocol.io/security.asc)