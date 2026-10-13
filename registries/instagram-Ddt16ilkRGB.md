# Workflow tool registry
Source: https://www.instagram.com/p/Ddt16ilkRGB/
Reviewed: 2026-10-14 (Asia/Dubai).

The post caption names the following five projects. Individual carousel slides were not fully inspected. Official repository documentation was checked.

| Tool | Official upstream | Workflow role | Installation / prerequisite |
| --- | --- | --- | --- |
| Jev Ultrafast | https://github.com/browser-use/jev-ultrafast | Browser task automation | Clone; uv sync; configure TYPESAFE_API_KEY and TEXT_MODEL_API_KEY. Live examples make paid API calls. |
| Laya | https://github.com/NandhaKishorM/laya | Local typed classification, choice, score and yes/no decisions | Python 3.10+; isolated venv; pip install laya; import/version check; download checkpoint and validate inference separately. |
| Google AX | https://github.com/google/ax | Distributed sandboxed agent orchestration | Go CLI plus Kubernetes, Agent Substrate, kubectl, ko and image registry for operation. |
| Hindsight | https://github.com/vectorize-io/hindsight | Persistent agent memory | Docker recommended; persistent volume; configure supported local/provider/subscription backend; bind local services to loopback. |
| Paperclip | https://github.com/paperclipai/paperclip | Agent work management, tickets and budgets | Node 24.11+, pnpm 9.15+; clone; pnpm install; pnpm dev. Source runner also needs Rust or compatible prebuilt runner. |

## Execution status
All five tracked source snapshots are now copied into vendors/ in this repository; each Git tree hash matches its pinned upstream commit. See source-lock.json for provenance.
The copy workflow passed: https://github.com/officegenuineinternational-gif/AI-Apps-and-Tools/actions/runs/38480876499
These are source snapshots, without upstream history or separate GitHub fork relationships. PC installation, local cloning and runtime validation remain pending.
Select tools when their role fits the workflow; verify actual installation and health before relying on them.
Do not treat source download, dependency installation, a running process and production certification as the same result.
No credentials belong in this repository.

## Verification required after setup
Record upstream commit, installed versions, dependency checks and per-tool smoke-test results.
Use separate environments and preserve existing configurations.
Test classification on non-sensitive fixtures; verify service health and restart behavior; validate browser actions on a harmless page.
Confirm Kubernetes/Substrate readiness before AX workloads.
Configure any paid-provider use separately from software installation.
