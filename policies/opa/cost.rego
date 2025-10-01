package bmad.cost

import rego.v1

# Cost control policy for BMAD operations
# Prevents budget overruns and enforces cost guardrails

default allow := false
default estimated_cost := 0

# Allow execution if cost is within limits
allow if {
    estimated_cost <= max_allowed_cost
    cost_tracking_enabled
    budget_approval_valid
}

# Calculate estimated cost based on resources and operations
estimated_cost := cost if {
    compute_cost := sum([
        node_compute_cost(node) |
        some node in input.dag.nodes
    ])
    
    storage_cost := sum([
        node_storage_cost(node) |
        some node in input.dag.nodes
    ])
    
    network_cost := sum([
        node_network_cost(node) |
        some node in input.dag.nodes
    ])
    
    cost := compute_cost + storage_cost + network_cost
}

# Maximum allowed cost based on intent constraints
max_allowed_cost := limit if {
    input.intent.cost_limit
    limit := to_number(trim_prefix(input.intent.cost_limit, "$"))
} else := 1000  # Default $1000 limit

# Cost calculation functions
node_compute_cost(node) := cost if {
    node.type == "mcp_call"
    cpu_cores := to_number(node.parameters.cpu_limit)
    memory_gb := to_number(node.parameters.memory_limit) / 1024
    duration_hours := to_number(node.parameters.estimated_duration) / 3600
    
    # AWS-like pricing: $0.0464 per vCPU hour + $0.0051 per GB memory hour
    cost := (cpu_cores * 0.0464 + memory_gb * 0.0051) * duration_hours
}

node_storage_cost(node) := cost if {
    node.mcp_server in ["aws-mcp", "k8s-mcp"]
    storage_gb := to_number(node.parameters.storage_size_gb)
    # EBS pricing: $0.10 per GB per month (prorated)
    cost := storage_gb * 0.10 / 720  # Per hour
} else := 0

node_network_cost(node) := cost if {
    node.parameters.data_transfer_gb
    transfer_gb := to_number(node.parameters.data_transfer_gb)
    # Data transfer: $0.09 per GB
    cost := transfer_gb * 0.09
} else := 0

# Cost tracking validation
cost_tracking_enabled if {
    input.session_metadata.cost_tracking == true
    input.session_metadata.billing_account
}

# Budget approval validation
budget_approval_valid if {
    estimated_cost <= 100  # Auto-approve under $100
} else if {
    estimated_cost > 100
    input.session_metadata.budget_approval_id
    input.session_metadata.approver
}

# Cost optimization recommendations
recommendations contains rec if {
    estimated_cost > max_allowed_cost * 0.8  # Alert at 80% of budget
    rec := {
        "type": "cost_optimization",
        "message": "Consider using spot instances to reduce costs",
        "potential_savings": estimated_cost * 0.3
    }
}

recommendations contains rec if {
    some node in input.dag.nodes
    node.mcp_server == "aws-mcp"
    to_number(node.parameters.cpu_limit) > 1000
    rec := {
        "type": "rightsizing",
        "message": sprintf("Node %s may be over-provisioned", [node.id]),
        "node_id": node.id
    }
}

# Cost alerts
deny contains msg if {
    estimated_cost > max_allowed_cost
    msg := sprintf("Estimated cost $%.2f exceeds limit $%.2f", [estimated_cost, max_allowed_cost])
}

deny contains msg if {
    estimated_cost > 5000  # Hard limit
    msg := "Execution cost exceeds absolute limit of $5000"
}

warn contains msg if {
    estimated_cost > max_allowed_cost * 0.9
    msg := sprintf("Cost warning: $%.2f is close to limit $%.2f", [estimated_cost, max_allowed_cost])
}