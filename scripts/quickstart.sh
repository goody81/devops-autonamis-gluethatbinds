#!/usr/bin/env bash
set -euo pipefail

# BMAD Protocol - 2-Minute Quickstart
# Demonstrates AI-native DevOps automation with local kind cluster

echo "🚀 BMAD 2-minute demo starting..."
echo "Building the reinforced-concrete skeleton of AI-native DevOps"

# Check prerequisites
command -v kind >/dev/null 2>&1 || { 
    echo "❌ Please install kind first: https://kind.sigs.k8s.io/docs/user/quick-start/"
    exit 1
}

command -v helm >/dev/null 2>&1 || { 
    echo "❌ Please install helm first: https://helm.sh/docs/intro/install/"
    exit 1
}

command -v kubectl >/dev/null 2>&1 || { 
    echo "❌ Please install kubectl first: https://kubernetes.io/docs/tasks/tools/"
    exit 1
}

# Set up demo environment
CLUSTER_NAME="bmad-demo"
NAMESPACE="bmad"

echo "🏗️  Setting up kind cluster..."
kind create cluster --name ${CLUSTER_NAME} --config tests/kind.yaml || {
    echo "⚠️  Cluster already exists, continuing..."
}

# Configure kubectl context
kubectl config use-context kind-${CLUSTER_NAME}

echo "📦 Installing BMAD helm chart..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install bmad helm/bmad \
    --namespace ${NAMESPACE} \
    --set image.tag=main \
    --set quickstart.enabled=true \
    --wait --timeout=300s

echo "🔧 Applying hello-bmad example..."
kubectl apply -f examples/00-hello-bmad/ -n ${NAMESPACE}

echo "⏳ Waiting for BMAD pipeline to turn green..."
echo "   This demonstrates natural language → DAG → deployment flow"

# Wait for TaskRuns to complete (Tekton-style)
timeout 120s bash -c '
    while true; do
        if kubectl get pods -n ${NAMESPACE} -l app=hello-bmad --no-headers 2>/dev/null | grep -q Running; then
            echo "✅ Hello BMAD pod is running!"
            break
        fi
        echo "   Still waiting for deployment..."
        sleep 5
    done
' || {
    echo "⚠️  Demo taking longer than expected, but continuing..."
}

echo "🎯 BMAD Demo Summary:"
echo "   - Kind cluster: ${CLUSTER_NAME}"
echo "   - Namespace: ${NAMESPACE}"
echo "   - Example app: hello-bmad"

echo ""
echo "🌐 Access points:"
echo "   Grafana:    http://localhost:3000 (admin/admin)"
echo "   Prometheus: http://localhost:9090"
echo "   API:        http://localhost:8080"

echo ""
echo "🧰 Try these commands:"
echo "   kubectl get pods -n ${NAMESPACE}"
echo "   kubectl logs -n ${NAMESPACE} -l app=bmad-planner"
echo "   kubectl port-forward -n ${NAMESPACE} svc/grafana 3000:3000"

echo ""
echo "📊 Starting port-forward to Grafana..."
echo "   Press Ctrl+C to stop the demo and cleanup"

# Set up port forwarding in background
kubectl port-forward -n ${NAMESPACE} svc/grafana 3000:3000 &
GRAFANA_PID=$!

kubectl port-forward -n ${NAMESPACE} svc/prometheus 9090:9090 &
PROMETHEUS_PID=$!

# Cleanup function
cleanup() {
    echo ""
    echo "🧹 Cleaning up demo environment..."
    kill ${GRAFANA_PID} ${PROMETHEUS_PID} 2>/dev/null || true
    
    read -p "Delete kind cluster? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kind delete cluster --name ${CLUSTER_NAME}
        echo "✅ Demo cluster deleted"
    else
        echo "💡 Cluster preserved. Delete manually with: kind delete cluster --name ${CLUSTER_NAME}"
    fi
}

# Set up signal handlers
trap cleanup EXIT INT TERM

echo "✅ BMAD demo is ready!"
echo "   Open http://localhost:3000 to explore the live DAG visualization"
echo "   Check the BMAD architecture in action with real telemetry"
echo ""
echo "Press Ctrl+C to cleanup and exit..."

# Keep script running
wait