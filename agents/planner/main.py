#!/usr/bin/env python3
"""
BMAD Planner Agent - Converts natural language intent to executable DAG
Combines PDDL planning with LLM reasoning for AI-native DevOps automation.
"""

import grpc
import json
import logging
import pydantic
import openai
from concurrent import futures
from typing import Dict, List, Optional

from bmad_pb2 import Intent, DAG, Node, Edge, PlanRequest, PlanResponse
from bmad_pb2_grpc import BMADServicer, add_BMADServicer_to_server
from policy_client import OPAClient

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class PlannerConfig(pydantic.BaseModel):
    """Configuration for the BMAD Planner"""
    openai_api_key: str
    opa_endpoint: str = "http://localhost:8181"
    max_dag_nodes: int = 100
    cost_threshold: float = 1000.0
    model: str = "gpt-4"


class PlannerServicer(BMADServicer):
    """BMAD Planner gRPC Service Implementation"""
    
    def __init__(self, config: PlannerConfig):
        self.config = config
        self.opa_client = OPAClient(config.opa_endpoint)
        openai.api_key = config.openai_api_key
        logger.info("BMAD Planner initialized")

    def Plan(self, request: PlanRequest, context) -> PlanResponse:
        """Convert natural language intent to executable DAG"""
        try:
            logger.info(f"Planning request: {request.intent.text}")
            
            # Step 1: Convert intent to PDDL using LLM
            pddl_goal = self._intent_to_pddl(request.intent)
            logger.info(f"Generated PDDL: {pddl_goal}")
            
            # Step 2: Build DAG from PDDL
            dag = self._build_dag_from_pddl(pddl_goal, request.intent)
            
            # Step 3: Validate against OPA policies
            policy_result = self.opa_client.check("executor.rego", dag)
            if not policy_result.allowed:
                logger.warning(f"Policy violation: {policy_result.reason}")
                return PlanResponse(
                    dag=dag,
                    warnings=[f"Policy violation: {policy_result.reason}"],
                    estimated_cost="0",
                    estimated_duration=0
                )
            
            # Step 4: Estimate cost and duration
            estimated_cost = self._estimate_cost(dag)
            estimated_duration = self._estimate_duration(dag)
            
            return PlanResponse(
                dag=dag,
                warnings=[],
                estimated_cost=str(estimated_cost),
                estimated_duration=estimated_duration
            )
            
        except Exception as e:
            logger.error(f"Planning failed: {e}")
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(f"Planning failed: {e}")
            return PlanResponse()

    def _intent_to_pddl(self, intent: Intent) -> str:
        """Convert natural language intent to PDDL goal"""
        prompt = f"""
        Convert the following DevOps intent to a PDDL goal:
        
        Intent: {intent.text}
        Context: {json.dumps(dict(intent.context))}
        Constraints: {intent.constraints}
        Cost Limit: {intent.cost_limit}
        
        Generate a PDDL goal that represents this intent using DevOps predicates:
        - deploy(service, version, environment)
        - scale(service, replicas)
        - configure(service, settings)
        - validate(service, checks)
        - rollback(service, version)
        
        Return only the PDDL goal expression.
        """
        
        response = openai.ChatCompletion.create(
            model=self.config.model,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=500,
            temperature=0.1
        )
        
        return response.choices[0].message.content.strip()

    def _build_dag_from_pddl(self, pddl_goal: str, intent: Intent) -> DAG:
        """Build executable DAG from PDDL goal"""
        nodes = []
        edges = []
        
        # Parse PDDL and map to MCP server calls
        # This is a simplified example - real implementation would use PDDL planner
        if "deploy" in pddl_goal.lower():
            # Add deployment nodes
            nodes.append(Node(
                id="validate-target",
                type="mcp_call",
                mcp_server="k8s-mcp",
                tool="kubectl",
                parameters={"action": "get", "resource": "nodes"}
            ))
            
            nodes.append(Node(
                id="deploy-service",
                type="mcp_call",
                mcp_server="k8s-mcp",
                tool="kubectl",
                parameters={"action": "apply", "manifest": "service.yaml"},
                dependencies=["validate-target"]
            ))
            
            nodes.append(Node(
                id="verify-deployment",
                type="validation",
                mcp_server="k8s-mcp",
                tool="kubectl",
                parameters={"action": "rollout", "resource": "status"},
                dependencies=["deploy-service"]
            ))
            
            # Add edges
            edges.extend([
                Edge(from="validate-target", to="deploy-service"),
                Edge(from="deploy-service", to="verify-deployment")
            ])
        
        return DAG(
            nodes=nodes,
            edges=edges,
            checksum=self._calculate_dag_checksum(nodes, edges),
            created_at=int(time.time())
        )

    def _estimate_cost(self, dag: DAG) -> float:
        """Estimate execution cost based on DAG complexity"""
        base_cost = 0.10  # Base cost per node
        return len(dag.nodes) * base_cost

    def _estimate_duration(self, dag: DAG) -> int:
        """Estimate execution duration in seconds"""
        base_duration = 30  # Base duration per node
        return len(dag.nodes) * base_duration

    def _calculate_dag_checksum(self, nodes: List[Node], edges: List[Edge]) -> str:
        """Calculate SHA256 checksum of DAG for integrity"""
        import hashlib
        dag_content = json.dumps({
            "nodes": [{"id": n.id, "type": n.type, "params": dict(n.parameters)} for n in nodes],
            "edges": [{"from": e.from_, "to": e.to} for e in edges]
        }, sort_keys=True)
        return hashlib.sha256(dag_content.encode()).hexdigest()


def serve():
    """Start the BMAD Planner gRPC server"""
    import os
    config = PlannerConfig(
        openai_api_key=os.getenv("OPENAI_API_KEY", ""),
        opa_endpoint=os.getenv("OPA_ENDPOINT", "http://localhost:8181")
    )
    
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    add_BMADServicer_to_server(PlannerServicer(config), server)
    
    listen_addr = '[::]:50051'
    server.add_insecure_port(listen_addr)
    server.start()
    
    logger.info(f"BMAD Planner listening on {listen_addr}")
    server.wait_for_termination()


if __name__ == "__main__":
    serve()