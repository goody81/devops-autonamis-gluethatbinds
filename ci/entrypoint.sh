#!/usr/bin/env bash
set -euo pipefail

# BMAD Runner Entrypoint
# Prepares firecracker environment and starts executor

echo "🚀 Starting BMAD Runner..."

# Set up firecracker permissions
sudo mkdir -p /srv/jailer
sudo chown bmad:bmad /srv/jailer

# Enable firecracker device access
sudo mknod /dev/kvm c 10 232 || true
sudo chmod 666 /dev/kvm || true

# Start containerd for firecracker-containerd
if ! pgrep containerd > /dev/null; then
    echo "Starting containerd..."
    sudo containerd &
    sleep 2
fi

# Wait for containerd socket
while [ ! -S /run/containerd/containerd.sock ]; do
    echo "Waiting for containerd socket..."
    sleep 1
done

# Start firecracker-containerd if not running
if ! pgrep firecracker-containerd > /dev/null; then
    echo "Starting firecracker-containerd..."
    sudo firecracker-containerd --config /etc/firecracker-containerd/config.toml &
    sleep 2
fi

# Verify firecracker is working
if command -v firecracker > /dev/null; then
    echo "✅ Firecracker available"
else
    echo "❌ Firecracker not found"
    exit 1
fi

# Set up eBPF tools if available
if command -v bpftool > /dev/null; then
    echo "✅ eBPF tools available"
else
    echo "⚠️  eBPF tools not found, continuing without"
fi

# Start the BMAD executor or run provided command
if [ $# -eq 0 ]; then
    echo "Starting BMAD executor..."
    exec /usr/local/bin/executor
else
    echo "Running command: $*"
    exec "$@"
fi