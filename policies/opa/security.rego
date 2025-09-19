package bmad.security

import rego.v1

# Security policy for BMAD operations
# Enforces security best practices and prevents malicious operations

default allow := false

# Allow execution if all security checks pass
allow if {
    input.dag
    no_security_violations
    supply_chain_verified
    secrets_properly_managed
    network_security_enforced
    audit_logging_enabled
}

# Check for security violations
no_security_violations if {
    not has_malicious_commands
    not has_privilege_escalation
    not has_data_exfiltration
    not has_crypto_mining
}

# Detect malicious commands
has_malicious_commands if {
    some node in input.dag.nodes
    some cmd in malicious_patterns
    contains(lower(node.parameters.command), cmd)
}

malicious_patterns := [
    "wget", "curl", "nc ", "netcat",
    "base64 -d", "/bin/sh", "/bin/bash",
    "reverse_shell", "backdoor",
    "rm -rf", "dd if=", ":(){ :|:& };:",
    "cryptominer", "monero", "bitcoin"
]

# Detect privilege escalation attempts
has_privilege_escalation if {
    some node in input.dag.nodes
    some escalation in privilege_escalation_patterns
    contains(lower(node.parameters.command), escalation)
}

privilege_escalation_patterns := [
    "sudo", "su -", "chmod 777", "chmod +s",
    "setuid", "setgid", "/etc/passwd", "/etc/shadow"
]

# Detect data exfiltration attempts
has_data_exfiltration if {
    some node in input.dag.nodes
    some pattern in data_exfil_patterns
    contains(lower(node.parameters.command), pattern)
}

data_exfil_patterns := [
    "scp ", "rsync", "ftp ", "sftp",
    "/proc/", "/sys/", "aws s3 cp",
    "kubectl get secret", "etcdctl get"
]

# Detect cryptocurrency mining
has_crypto_mining if {
    some node in input.dag.nodes
    some pattern in crypto_patterns
    contains(lower(node.parameters.command), pattern)
}

crypto_patterns := [
    "xmrig", "cpuminer", "cgminer",
    "stratum+tcp", "mining pool",
    "hashrate", "difficulty"
]

# Supply chain verification
supply_chain_verified if {
    every node in input.dag.nodes {
        node.type == "mcp_call"
        mcp_server_trusted(node.mcp_server)
        image_signature_valid(node)
    }
}

mcp_server_trusted(server) if {
    server in trusted_mcp_servers
}

trusted_mcp_servers := [
    "aws-mcp", "k8s-mcp", "terraform-mcp",
    "github-mcp-server", "docker-mcp"
]

image_signature_valid(node) if {
    node.parameters.image_signature
    node.parameters.cosign_verified == "true"
    node.parameters.slsa_level >= 2
}

# Secrets management validation
secrets_properly_managed if {
    every node in input.dag.nodes {
        node.type == "mcp_call"
        secrets_not_hardcoded(node)
        spiffe_certs_used(node)
    }
}

secrets_not_hardcoded(node) if {
    not contains(node.parameters.command, "password=")
    not contains(node.parameters.command, "token=")
    not contains(node.parameters.command, "api_key=")
    not regex.match("[A-Za-z0-9]{20,}", node.parameters.command)
}

spiffe_certs_used(node) if {
    node.parameters.spiffe_id
    node.parameters.cert_ttl_minutes <= 15  # 15-minute cert rotation
}

# Network security enforcement
network_security_enforced if {
    every node in input.dag.nodes {
        node.parameters.network_policy
        node.parameters.egress_allowed == ["necessary_services"]
        node.parameters.tls_enabled == "true"
    }
}

# Audit logging verification
audit_logging_enabled if {
    input.session_metadata.audit_enabled == true
    input.session_metadata.log_retention_days >= 2555  # 7 years
    input.session_metadata.merkle_root_enabled == true
}

# Security recommendations
recommendations contains rec if {
    some node in input.dag.nodes
    not node.parameters.readonly_filesystem
    rec := {
        "type": "security_hardening",
        "message": sprintf("Enable read-only filesystem for node %s", [node.id]),
        "node_id": node.id,
        "severity": "medium"
    }
}

recommendations contains rec if {
    some node in input.dag.nodes
    to_number(node.parameters.cert_ttl_minutes) > 15
    rec := {
        "type": "certificate_rotation",
        "message": sprintf("Reduce certificate TTL for node %s to 15 minutes", [node.id]),
        "node_id": node.id,
        "severity": "high"
    }
}

# Security violations
deny contains msg if {
    has_malicious_commands
    msg := "Malicious commands detected in DAG"
}

deny contains msg if {
    has_privilege_escalation
    msg := "Privilege escalation attempts detected"
}

deny contains msg if {
    has_data_exfiltration
    msg := "Data exfiltration patterns detected"
}

deny contains msg if {
    has_crypto_mining
    msg := "Cryptocurrency mining patterns detected"
}

deny contains msg if {
    not supply_chain_verified
    msg := "Supply chain verification failed"
}

deny contains msg if {
    not secrets_properly_managed
    msg := "Secrets management violations detected"
}

# Helper functions
contains(str, substr) if {
    indexof(str, substr) != -1
}

lower(str) := strings.lower(str)