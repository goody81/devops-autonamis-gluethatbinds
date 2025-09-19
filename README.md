# 🏗️ BMAD Protocol

**Build-Manage-Autonomously-Deploy** – the reinforced-concrete skeleton of AI-native DevOps.

![CI](https://github.com/bmad-protocol/bmad/actions/workflows/ci.yml/badge.svg)
![Release](https://img.shields.io/github/v/release/bmad-protocol/bmad)
![License](https://img.shields.io/badge/license-MIT-green)
![Security](https://securityscorecards.dev/viewer/?uri=github.com/bmad-protocol/bmad)

<p align="center">
  <img src="docs/img/demo.gif" width="800" alt="bmad deploy in 20 s">
</p>

## 🔥 What & Why

Traditional CI/CD is manual, brittle, reactive.

BMAD is a deterministic, auditable, self-evolving DevOps skyscraper:

- **Natural-language intent → provable DAG → zero-downtime deploy.**
- **80+ MCP servers** (K8s, AWS, Terraform, GitHub, …) auto-discovered.
- **Every step runs in a firecracker micro-VM**, eBPF-sandboxed, cosign-signed.
- **Continuous verification**: SMT solvers, unit tests, CVE scans, cost guardrails.
- **Post-mortem Merkle-rooted**; full replayability for 7 years.

## ⚡ 2-Minute Quick Start

```bash
git clone https://github.com/bmad-protocol/bmad.git
cd bmad
./scripts/quickstart.sh
# → kind cluster, sample nginx, auto-teardown
```

Open http://localhost:3000 to watch the live DAG.

## 🧰 CLI Cheatsheet

```bash
bmad deploy --intent "upgrade prod to v3.4.2, canary 10%, cost < $200"
bmad watch  --uid 7f3a9
bmad replay  --node 4c2b --from-snapshot
bmad audit   --standard soc2 --from-tag v3.4.2
```

## 🔧 Integrations

| Platform | Status | MCP Server |
|----------|--------|------------|
| AWS | ✅ | awslabs/mcp |
| Kubernetes | ✅ | kubectl-mcp-server |
| Terraform | ✅ | tfmcp |
| GitHub | ✅ | github-mcp-server |
| Azure | beta | ado-mcp |
| GCP | roadmap | — |

## 📊 Telemetry

Prometheus + VictoriaMetrics + Grafana out-of-the-box:
- http://localhost:9090 | http://localhost:3001

## 🛡️ Security & Compliance

- **Supply-chain**: cosign + in-toto + SLSA level 3
- **Runtime**: eBPF syscall allow-list
- **Secrets**: SPIFFE 15-min certs
- **Evidence packs**: CIS, SOC-2, GDPR auto-generated

## 🏗️ Architecture

```
┌────────────┐  gRPC  ┌────────────┐  NATS  ┌────────────┐
│  Planner   │◄──────►│  Executor  │◄──────►│ Verifier   │
└────────────┘        └────────────┘        └────────────┘
       ▲                     ▲                     ▲
       │ PDDL                │ firecracker         │ SMT
       ▼                     ▼                     ▼
┌────────────┐        ┌────────────┐        ┌────────────┐
│Policy LLM  │        │ ToolForge  │        │Telemetry   │
│  (OPA+RL)  │        │ 80+ MCPs   │        │ Lakehouse  │
└────────────┘        └────────────┘        └────────────┘
```

Deep-dive: [docs/architecture.md](docs/architecture.md)

## 🤝 Contributing

We love MCP wrappers, chaos experiments, policy tweaks.

See [CONTRIBUTING.md](CONTRIBUTING.md) and [good-first-issues](https://github.com/bmad-protocol/bmad/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22).

## 📄 License

MIT – see [LICENSE](LICENSE).

## 🙏 Acknowledgements

Julius, Manus, GenSpark, DeepAgent, [awesome-mcp-servers](https://github.com/punkpeye/awesome-mcp-servers), [firecracker-containerd](https://github.com/firecracker-microvm/firecracker-containerd), [VictoriaMetrics](https://github.com/VictoriaMetrics/VictoriaMetrics), [Open Policy Agent](https://github.com/open-policy-agent/opa), and 200+ open-source projects we shamelessly fused into rebar-and-concrete.