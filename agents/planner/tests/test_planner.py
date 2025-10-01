import pytest
import unittest.mock as mock
from agents.planner.main import PlannerServicer, PlannerConfig
from bmad_pb2 import Intent, PlanRequest


class TestPlannerServicer:
    """Unit tests for BMAD Planner"""
    
    @pytest.fixture
    def config(self):
        return PlannerConfig(
            openai_api_key="test-key",
            opa_endpoint="http://localhost:8181"
        )
    
    @pytest.fixture
    def planner(self, config):
        with mock.patch('agents.planner.main.OPAClient'):
            return PlannerServicer(config)
    
    def test_intent_to_pddl_simple_deploy(self, planner):
        """Test converting simple deployment intent to PDDL"""
        intent = Intent(
            text="deploy nginx to production",
            context={"environment": "prod"},
            constraints=["cost < $100"],
            cost_limit="$100"
        )
        
        with mock.patch('openai.ChatCompletion.create') as mock_openai:
            mock_openai.return_value.choices[0].message.content = "deploy(nginx, latest, production)"
            
            pddl = planner._intent_to_pddl(intent)
            assert "deploy" in pddl.lower()
            assert "nginx" in pddl.lower()
    
    def test_build_dag_from_pddl(self, planner):
        """Test building DAG from PDDL goal"""
        pddl_goal = "deploy(nginx, latest, production)"
        intent = Intent(text="deploy nginx")
        
        dag = planner._build_dag_from_pddl(pddl_goal, intent)
        
        assert len(dag.nodes) > 0
        assert len(dag.edges) >= 0
        assert dag.checksum
        assert dag.created_at > 0
        
        # Check that nodes have required fields
        for node in dag.nodes:
            assert node.id
            assert node.type
            if node.type == "mcp_call":
                assert node.mcp_server
                assert node.tool
    
    def test_estimate_cost(self, planner):
        """Test cost estimation for DAG"""
        from bmad_pb2 import DAG, Node
        
        dag = DAG()
        dag.nodes.extend([
            Node(id="node1", type="mcp_call"),
            Node(id="node2", type="validation"),
            Node(id="node3", type="mcp_call")
        ])
        
        cost = planner._estimate_cost(dag)
        assert cost > 0
        assert isinstance(cost, float)
        # Should be 3 nodes * base cost
        assert cost == 3 * 0.10
    
    def test_estimate_duration(self, planner):
        """Test duration estimation for DAG"""
        from bmad_pb2 import DAG, Node
        
        dag = DAG()
        dag.nodes.extend([
            Node(id="node1", type="mcp_call"),
            Node(id="node2", type="validation")
        ])
        
        duration = planner._estimate_duration(dag)
        assert duration > 0
        assert isinstance(duration, int)
        # Should be 2 nodes * base duration
        assert duration == 2 * 30
    
    def test_calculate_dag_checksum(self, planner):
        """Test DAG checksum calculation"""
        from bmad_pb2 import Node, Edge
        
        nodes = [
            Node(id="node1", type="mcp_call", parameters={"action": "deploy"}),
            Node(id="node2", type="validation")
        ]
        edges = [Edge(from_="node1", to="node2")]
        
        checksum1 = planner._calculate_dag_checksum(nodes, edges)
        checksum2 = planner._calculate_dag_checksum(nodes, edges)
        
        # Same input should produce same checksum
        assert checksum1 == checksum2
        assert len(checksum1) == 64  # SHA256 hex length
        
        # Different input should produce different checksum
        nodes[0].parameters["action"] = "update"
        checksum3 = planner._calculate_dag_checksum(nodes, edges)
        assert checksum1 != checksum3
    
    @mock.patch('agents.planner.main.openai.ChatCompletion.create')
    def test_plan_request_success(self, mock_openai, planner):
        """Test successful plan request"""
        # Mock OpenAI response
        mock_openai.return_value.choices[0].message.content = "deploy(nginx, latest, production)"
        
        # Mock OPA client
        planner.opa_client.check.return_value.allowed = True
        
        request = PlanRequest(
            intent=Intent(
                text="deploy nginx to production",
                cost_limit="$100"
            ),
            session_id="test-session"
        )
        
        context = mock.Mock()
        response = planner.Plan(request, context)
        
        assert response.dag
        assert len(response.dag.nodes) > 0
        assert response.estimated_cost
        assert response.estimated_duration > 0
        assert len(response.warnings) == 0
    
    @mock.patch('agents.planner.main.openai.ChatCompletion.create')
    def test_plan_request_policy_violation(self, mock_openai, planner):
        """Test plan request with policy violation"""
        # Mock OpenAI response
        mock_openai.return_value.choices[0].message.content = "deploy(nginx, latest, production)"
        
        # Mock OPA client to deny
        planner.opa_client.check.return_value.allowed = False
        planner.opa_client.check.return_value.reason = "Cost exceeds limit"
        
        request = PlanRequest(
            intent=Intent(text="deploy expensive service"),
            session_id="test-session"
        )
        
        context = mock.Mock()
        response = planner.Plan(request, context)
        
        assert response.dag
        assert len(response.warnings) > 0
        assert "Policy violation" in response.warnings[0]