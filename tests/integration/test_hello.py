import pytest
import time
import requests


def test_nginx_endpoint():
    """Test that the hello-bmad nginx endpoint returns 200"""
    url = "http://hello-bmad.local"
    
    for attempt in range(30):  # Try for up to 60 seconds
        try:
            response = requests.get(url, timeout=2)
            if response.status_code == 200:
                assert "BMAD Protocol" in response.text
                return
        except requests.exceptions.RequestException:
            pass
        
        time.sleep(2)
    
    pytest.fail("Never got 200 from nginx endpoint")


def test_bmad_components_health():
    """Test that BMAD components are healthy"""
    components = [
        ("planner", "http://localhost:50051/health"),
        ("executor", "http://localhost:50052/health"),
        ("verifier", "http://localhost:50053/health"),
    ]
    
    for component, health_url in components:
        try:
            response = requests.get(health_url, timeout=5)
            assert response.status_code == 200, f"{component} health check failed"
        except requests.exceptions.RequestException:
            # Components may not be running in test environment
            pytest.skip(f"{component} not available for health check")


def test_grafana_dashboard():
    """Test that Grafana is accessible"""
    try:
        response = requests.get("http://localhost:3000/api/health", timeout=5)
        assert response.status_code == 200
        
        health_data = response.json()
        assert health_data.get("database") == "ok"
    except requests.exceptions.RequestException:
        pytest.skip("Grafana not available for testing")


def test_prometheus_metrics():
    """Test that Prometheus is collecting metrics"""
    try:
        response = requests.get("http://localhost:9090/api/v1/query", 
                              params={"query": "up"}, timeout=5)
        assert response.status_code == 200
        
        metrics_data = response.json()
        assert metrics_data.get("status") == "success"
    except requests.exceptions.RequestException:
        pytest.skip("Prometheus not available for testing")