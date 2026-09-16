---
name: ghidra-workflows
description: Use Ghidra or PyGhidra for repeatable import, auto-analysis, decompilation, cross-reference tracing, datatype recovery, annotation, and headless exports.
---

# Ghidra Workflows

1. Verify the target hash and architecture first. Store projects only under `tmp/ghidra_<id>/`.
2. Record import format, language/compiler specification, image base, loader options, and analysis options.
3. Let auto-analysis complete before drawing conclusions; capture warnings and failed analyzers.
4. Navigate from imports, exports, strings, entry points, handlers, and cross-references. Rename functions and variables only when evidence supports the name.
5. Recover structures and calling conventions iteratively; check the disassembly whenever decompiler output looks suspicious.
6. Use PyGhidra or headless scripts for repeatable bulk tasks and export scripts/results to `artifacts/<id>/` when requested.
7. In reports, cite program offsets/addresses, function names, decompiler assumptions, and evidence. Do not treat decompiled C as original source.
