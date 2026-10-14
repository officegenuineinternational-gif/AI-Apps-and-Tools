# AI Apps and Tools

Five exact upstream source snapshots are stored in this repository.

| Tool | Source folder | Files verified |
| --- | --- | ---: |
| Jev Ultrafast | [vendors/jev-ultrafast](vendors/jev-ultrafast) | 40 |
| Laya | [vendors/laya](vendors/laya) | 1,188 |
| Google AX | [vendors/ax](vendors/ax) | 64 |
| Hindsight | [vendors/hindsight](vendors/hindsight) | 5,124 |
| Paperclip | [vendors/paperclip](vendors/paperclip) | 10,245 |

Total: 16,661 upstream files. Original licences and documentation are retained.
Each folder's Git tree hash was independently verified against its upstream commit.
These are source snapshots, without upstream Git history or separate GitHub fork relationships.

[Source commits](registries/source-lock.json) · [Tool requirements](registries/instagram-Ddt16ilkRGB.md) · [Successful copy job](https://github.com/officegenuineinternational-gif/AI-Apps-and-Tools/actions/runs/38480876499)

## Clone to Windows
Run in PowerShell from the desired parent directory:

```powershell
git -c core.longpaths=true clone https://github.com/officegenuineinternational-gif/AI-Apps-and-Tools.git AI-Workflow-Tools
```

Then use each tool's README in its source folder for installation.
Cloning alone does not install dependencies or start services.
Windows setup must account for symlink support and each tool's runtime requirements.

## Status
Source copying and integrity verification completed on 14 October 2026 (Asia/Dubai).
PC installation and live runtime testing remain pending; no production readiness is claimed.
Do not store credentials in this public repository.

## Windows installer
The installer is prepared in [scripts/Install-WorkflowTools.ps1](scripts/Install-WorkflowTools.ps1).
It verifies all five pinned source tree hashes and rejects tracked source changes before installation.
It installs Python tools into separate environments, builds the AX CLI and Paperclip, and records each result in a local installation-status.json.

Required commands: Git, uv, Node 24.11+, pnpm and Go (AX source requests Go 1.27.1). Paperclip native dependencies may also require Rust.
Missing prerequisites and installation failures are reported separately per tool.
Services, provider credentials, Kubernetes, model inference and production certification are separate subsequent steps.

From PowerShell in this cloned repository:

```powershell
.\scripts\Install-WorkflowTools.ps1 -CheckOnly
.\scripts\Install-WorkflowTools.ps1
```

Installer preparation is not evidence of installation on the office PC.

## Windows installation findings (14 October 2026)
Office-PC logs confirm successful imports for Jev Ultrafast, Laya 0.4.6 and Hindsight, plus Laya dependency compatibility. Services and inference remain unverified.

AX's pinned source uses Unix-only process APIs and does not compile natively for Windows. The installer now builds a Linux amd64 CLI for use in a suitable WSL/Linux environment; Kubernetes and Agent Substrate are still required for operation.

Paperclip's pinned source has a stale dependency lockfile. The installer preserves vendors/paperclip and copies it into the local installation root's apps/paperclip folder. It repairs the lockfile there without lifecycle scripts, validates it with frozen mode, then installs and builds using that lockfile. The Windows runtime copy also normalizes line endings for generated-file checks, refreshes the derived PRP protocol manifest, replaces one Unix-only file-copy command with a Node helper, and runs Unix package scripts through Git Bash. The pinned vendor snapshot remains unchanged. Windows CI verified legacy status-file handling, Git Bash script execution, source blob integrity, lock repair, asset copying and the AX cross-build in [run 38559690237](https://github.com/officegenuineinternational-gif/AI-Apps-and-Tools/actions/runs/38559690237). The office-PC Paperclip build remains pending.

Retry the remaining Paperclip build after pulling updates:

```powershell
git pull --ff-only
.\scripts\Install-WorkflowTools.ps1 -Only ax,paperclip
```
