# RE Shell agent guidance

This repository is an agent-neutral reverse-engineering workbench. The Nix flake provides tools; reusable workflows live only under `skills/` and follow the open Agent Skills format.

## Operating rules

- Work only on targets the user is authorized to analyze. Do not help deploy malware, steal credentials, evade detection, or access systems without permission.
- Start with non-destructive identification and static analysis. Ask before executing unknown binaries, attaching to live processes, changing devices, flashing firmware, or sending traffic to third-party systems.
- Preserve originals. Record SHA-256 hashes before analysis and write intermediate output beneath `tmp/`.
- Put requested durable deliverables beneath `artifacts/<meaningful-id>/`. Do not put generated analysis output in the repository root.
- Prefer reproducible CLI commands and record tool versions, assumptions, and evidence. Clearly separate observations from inference.
- Never expose secrets found during analysis. Redact them in reports unless the user explicitly needs an exact value and is authorized to receive it.

## Skills

Select the most specific matching workflow from `skills/`. Use `general-re` for initial triage and shared conventions, then add a platform or technique skill when appropriate. Read each selected `SKILL.md` before acting.

Available skills: `general-re`, `binary-triage`, `linux-elf-re`, `firmware-re`, `android-re`, `windows-re`, `web-re`, `network-protocol-re`, `malware-analysis`, `ghidra-workflows`, and `frida-workflows`.

User instructions take precedence over workflow defaults unless they conflict with authorization, safety, or preservation requirements.
