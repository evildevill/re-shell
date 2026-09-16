---
name: binary-triage
description: Safely identify and prioritize unknown binaries, archives, disk images, memory dumps, and suspicious samples before deeper analysis.
---

# Binary Triage

Use this workflow before platform-specific analysis when the target is unknown or potentially hostile.

1. Confirm scope and locate the exact input without executing it.
2. Create `tmp/triage_<id>/` and an `artifacts/<id>/` directory only when a durable report is requested.
3. Record size and cryptographic hashes (`sha256sum`, plus other hashes only when useful).
4. Identify type with `file`, magic bytes, container metadata, and `exiftool`; do not trust the extension.
5. Inspect archive members before extraction. Extract into `tmp/`, preserving the original.
6. Collect strings, headers, sections, symbols, imports, entropy indicators, signatures, and packer/compiler evidence with format-appropriate tools.
7. Scan with relevant YARA rules and explain rule provenance. A rule match is evidence, not a verdict.
8. Choose the next skill from observed format: `linux-elf-re`, `windows-re`, `android-re`, `firmware-re`, `web-re`, or `malware-analysis`.
9. Write findings with exact commands, tool versions, hashes, evidence paths, limitations, and recommended next steps.

Never execute an untrusted target during triage. Use an isolated environment for any later dynamic analysis and obtain confirmation first.
