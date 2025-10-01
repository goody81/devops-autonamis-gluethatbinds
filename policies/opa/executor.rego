package bmad.executor

import rego.v1

# Executor policy for validating DAG execution safety
# Ensures all operations run in secure, sandboxed environments

default allow := false

# Allow execution if all safety checks pass
allow if {
    input.dag
    dag_structure_valid
    firecracker_isolation_enabled
    resource_limits_defined
    no_privileged_operations
    ebpf_sandbox_configured
}

# Validate DAG structure integrity
dag_structure_valid if {
    input.dag.nodes
    input.dag.edges
    input.dag.checksum
    count(input.dag.nodes) > 0
    count(input.dag.nodes) <= 100  # Maximum DAG complexity
}

# Ensure firecracker micro-VM isolation
firecracker_isolation_enabled if {
    every node in input.dag.nodes {
        node.type == "mcp_call"
        "firecracker_vm_id" in node.parameters
    }
}

# Validate resource limits for each node
resource_limits_defined if {
    every node in input.dag.nodes {
        node.parameters.cpu_limit
        node.parameters.memory_limit
        to_number(node.parameters.cpu_limit) <= 2000  # Max 2 CPU cores
        to_number(node.parameters.memory_limit) <= 4096  # Max 4GB memory
    }
}

# Block privileged operations
no_privileged_operations if {
    every node in input.dag.nodes {
        not contains(node.parameters.command, "sudo")
        not contains(node.parameters.command, "chmod +x")
        not contains(node.parameters.command, "/etc/")
        not node.parameters.privileged == "true"
    }
}

# Ensure eBPF syscall filtering is configured
ebpf_sandbox_configured if {
    every node in input.dag.nodes {
        node.parameters.ebpf_policy
        node.parameters.ebpf_policy in ["strict", "medium", "basic"]
    }
}

# Additional validation rules
deny contains msg if {
    some node in input.dag.nodes
    not node.mcp_server
    msg := sprintf("Node %s missing MCP server specification", [node.id])
}

deny contains msg if {
    some node in input.dag.nodes
    node.type == "mcp_call"
    not node.tool
    msg := sprintf("MCP call node %s missing tool specification", [node.id])
}

deny contains msg if {
    input.dag.nodes
    execution_time_estimate > 3600  # Max 1 hour execution
    msg := "Estimated execution time exceeds 1 hour limit"
}

# Helper functions
execution_time_estimate := sum([
    30 |  # Base 30 seconds per node
    some node in input.dag.nodes
])

contains(str, substr) if {
    indexof(str, substr) != -1
}