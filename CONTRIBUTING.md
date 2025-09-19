# Contributing to BMAD Protocol

Welcome to the BMAD Protocol! We're building the reinforced-concrete skeleton of AI-native DevOps, and we'd love your help.

## 🚀 Quick Start for Contributors

1. **Fork** the repository
2. **Branch** from main: `git checkout -b feat/your-awesome-feature`
3. **Wrap new tools** via cookiecutter:
   ```bash
   cookiecutter toolforge/_template/ -o toolforge/my-tool
   ```
4. **Test** your changes:
   ```bash
   ./scripts/quickstart.sh
   pytest tests/
   ```
5. **Sign** your commits: `git commit -S -m "feat: your awesome feature"`
6. **Open** a Pull Request with our template filled

## 🧰 Development Environment

### Prerequisites
- Go 1.21+
- Python 3.11+
- Docker & Kind
- Helm 3.x
- kubectl

### Local Setup
```bash
git clone https://github.com/bmad-protocol/bmad.git
cd bmad
./scripts/quickstart.sh
```

## 🏗️ Architecture Overview

BMAD consists of three core agents:

1. **Planner** (`agents/planner/`) - PDDL + LLM hybrid planning
2. **Executor** (`agents/executor/`) - Firecracker micro-VM execution
3. **Verifier** (`agents/verifier/`) - SMT + unit-test validation

### Adding MCP Servers

We welcome new MCP server integrations! Use our template:

```bash
cookiecutter toolforge/_template/
```

This generates:
- MCP server wrapper
- OPA policies
- Integration tests
- Documentation

### Core Components

- **ToolForge** (`toolforge/`) - MCP server registry and management
- **Policies** (`policies/`) - OPA/Rego security and cost policies
- **Telemetry** (`telemetry/`) - Prometheus + Grafana monitoring
- **Examples** (`examples/`) - Reference deployments

## 🧪 Testing

We use multiple testing layers:

### Unit Tests
```bash
# Python agents
pytest agents/planner/tests/
pytest agents/verifier/tests/

# Go executor
go test ./agents/executor/...
```

### Integration Tests
```bash
# Full pipeline test
cd tests/integration
kind create cluster --config ../kind.yaml
helm install bmad ../../helm/bmad
pytest test_hello.py
```

### Fuzz Testing
```bash
# Protocol buffer fuzzing
cd tests/fuzz
go-fuzz-build
go-fuzz
```

## 📋 Pull Request Checklist

- [ ] Tests pass locally (`pytest` + `go test`)
- [ ] Code follows style guidelines (black, gofmt)
- [ ] Commits are signed (`git commit -S`)
- [ ] Documentation updated (if applicable)
- [ ] Integration test included (for new features)
- [ ] Security review completed (for sensitive changes)
- [ ] Cost impact assessed (for infrastructure changes)

## 🎯 Areas We Need Help

### High Priority
- **MCP Server Wrappers**: Azure, GCP, ArgoCD, Flux
- **Policy Examples**: Industry-specific compliance (HIPAA, PCI-DSS)
- **Documentation**: Architecture diagrams, tutorials
- **Performance**: Executor optimization, caching

### Good First Issues
Look for issues labeled [`good first issue`](https://github.com/bmad-protocol/bmad/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22).

Common starter tasks:
- Add MCP server using template
- Improve error messages
- Write integration tests
- Update documentation

## 🔒 Security

- All commits must be signed
- Security-sensitive changes need maintainer review
- Follow responsible disclosure for vulnerabilities
- Use secrets management (never hardcode credentials)

## 📊 Performance Guidelines

- Keep DAG execution under 1 hour
- Limit firecracker VMs to 2 CPU cores / 4GB RAM
- Use efficient OPA policies (avoid recursive rules)
- Optimize for P99 latency under 5 seconds

## 🏷️ Commit Convention

We follow [Conventional Commits](https://conventionalcommits.org/):

```
feat: add new terraform-mcp integration
fix: resolve memory leak in executor
docs: update architecture diagrams
test: add integration test for cost policies
chore: update dependencies
```

Types: `feat`, `fix`, `docs`, `test`, `chore`, `refactor`, `perf`, `ci`

## 📞 Getting Help

- **Discord**: [BMAD Community](https://discord.gg/bmad-protocol)
- **GitHub Discussions**: For design questions
- **Issues**: For bugs and feature requests
- **Email**: maintainers@bmad-protocol.io

## 🎉 Recognition

Contributors get:
- Listed in our README acknowledgements
- Invitation to quarterly contributor calls
- Early access to new features
- BMAD swag (stickers, t-shirts)

## 📜 Code of Conduct

Be excellent to each other. We follow the [Contributor Covenant](CODE_OF_CONDUCT.md).

---

**Thank you for helping build the future of AI-native DevOps!** 🏗️