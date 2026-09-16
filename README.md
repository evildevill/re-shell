# RE Shell

An agent-neutral reverse-engineering workbench: a reproducible Nix toolchain plus portable [Agent Skills](https://agentskills.io/) for Codex, ChatGPT, Claude Code, and other compatible agents.

```text
                         Codex / ChatGPT
                        /                \
target -> skills/ -> shell tools          artifacts/
                        \                /
                         Claude / others
```

The agent is the analyst; Nix is the workshop. RE Shell does not reimplement Ghidra, radare2, Frida, JADX, binwalk, mitmproxy, YARA, or the other tools it packages. It teaches compatible agents how to select and use them safely, consistently, and reproducibly.

## Quick start

Install [Nix](https://nixos.org/download/) with flakes enabled, clone the repository, and enter the environment:

```sh
git clone https://github.com/schlarpc/re-shell.git
cd re-shell
nix develop
```

Then launch any supported agent from the repository root:

```sh
codex
# or
claude
```

Example requests:

```text
Triage suspicious.exe without executing it and write a report.
Analyze firmware.bin and document its update and rollback mechanism.
Decompile this APK and identify hardcoded endpoints.
Reconstruct the application protocol in capture.pcapng.
```

Generated scratch work belongs in `tmp/`; requested durable deliverables belong in `artifacts/<identifier>/`. Both stay local and are gitignored.

## Architecture

`skills/` is the single source of truth. Both the portable Agent Plugins format and Claude Code discover root-level skills, so the repository does not maintain divergent `.claude/skills` and `.codex/skills` copies.

| Component | Purpose |
|---|---|
| `skills/` | Canonical, portable workflows |
| `plugin.json` | Portable Agent Plugins manifest |
| `.codex-plugin/plugin.json` | OpenAI compatibility manifest and presentation metadata |
| `.claude-plugin/plugin.json` | Claude Code compatibility manifest |
| `AGENTS.md` | Concise Codex/project operating rules |
| `CLAUDE.md` | Concise Claude Code adapter |
| `flake.nix` | Reproducible RE toolchain and environment |

### Included skills

| Skill | Use it for |
|---|---|
| `general-re` | Shared tools, artifact conventions, hardware, USB, FPGA, and embedded context |
| `binary-triage` | Safe identification and prioritization of unknown samples |
| `linux-elf-re` | ELF executables, libraries, loaders, and native Unix code |
| `firmware-re` | Firmware containers, filesystems, boot chains, and update mechanisms |
| `android-re` | APK, DEX, smali, Android images, ADB, and mobile instrumentation |
| `windows-re` | PE, .NET, Windows installers, malware, and memory images |
| `web-re` | HAR, HTTP, WebSocket, protobuf, gRPC, and TLS behavior |
| `network-protocol-re` | PCAP/PCAPNG, framing, state machines, and unknown protocols |
| `malware-analysis` | Authorized defensive analysis and IOC extraction |
| `ghidra-workflows` | Repeatable Ghidra/PyGhidra analysis and exports |
| `frida-workflows` | Authorized runtime observation and reusable hooks |

Skills activate from their descriptions. Invoke one explicitly with the syntax supported by your agent, such as `$firmware-re` in Codex, or simply describe the task and target.

## Plugin use

RE Shell is already laid out as a skills-only portable plugin. The root `plugin.json` follows the Agent Plugins schema, while OpenAI and Claude compatibility manifests support their current authoring paths.

For Codex/ChatGPT development, add this folder to a local marketplace with the built-in `$plugin-creator`, refresh the app, install **RE Shell**, and test it in a new conversation. A published version can be submitted once to the universal plugin directory shared by ChatGPT and Codex.

For Claude Code, the root `skills/` directory and `.claude-plugin/` metadata form a standard plugin and marketplace package:

```sh
claude plugin marketplace add /absolute/path/to/re-shell
claude plugin install re-shell@re-shell
```

The Nix toolchain is local. Installing only the skill package on a remote or hosted agent does not magically install system binaries; run the agent inside `nix develop`, or install the flake package and propagate the environment variables exposed by `lib.<system>.envVars`.

## Adding a workflow or tool

1. Add a focused `skills/<name>/SKILL.md` with standard `name` and trigger-rich `description` front matter.
2. Put shared binaries in the appropriate section of `flake.nix`; add Python and Node dependencies through `pyproject.toml` and `package.json`.
3. Keep conditional detail in `references/` and deterministic repeatable automation in `scripts/` within that skill.
4. Validate the skill and the plugin manifests, then test automatic selection with representative requests.

## Safety

Use RE Shell only on software, devices, captures, and systems you own or are authorized to analyze. The workflows default to non-destructive static analysis, preserve originals, require confirmation before risky dynamic actions, and prohibit assistance that deploys malware, steals credentials, evades detection, or accesses systems without permission.

## Upstream and licensing

This work is based on [`schlarpc/re-shell`](https://github.com/schlarpc/re-shell) and preserves its project identity and history. At the time of this conversion, the checked-out upstream tree does not contain a `LICENSE` file. Do not assume that absence grants redistribution rights; clarify the upstream license before publishing a fork or plugin release, then add the correct license and attribution files without changing their terms.
