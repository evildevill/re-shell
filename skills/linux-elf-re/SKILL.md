---
name: linux-elf-re
description: Analyze Linux and Unix ELF executables, shared libraries, core dumps, symbols, relocations, loaders, and native x86, ARM, MIPS, or RISC-V code.
---

# Linux and ELF Reverse Engineering

Start with `binary-triage` and preserve the original hash.

1. Inspect ELF class, endianness, architecture, ABI, program headers, section headers, dynamic entries, relocations, symbols, and notes using `readelf`, `objdump`, `nm`, and `file`.
2. Identify interpreter, RPATH/RUNPATH, required libraries, exported APIs, constructors, and security properties. Do not run `ldd` on an untrusted executable; inspect dynamic metadata instead.
3. Use `strings` and cross-reference interesting text from disassembly or decompiler output.
4. Use `rizin`/`radare2` for fast control-flow analysis and `ghidra-workflows` for deeper decompilation and annotation.
5. For stripped code, infer function boundaries from callers, unwind data, relocations, library signatures, and behavior—not names alone.
6. Put databases, decompilation, extracted resources, and patched copies under `tmp/`. Keep the original immutable.
7. Before dynamic analysis, document architecture, loader needs, input surface, network behavior, and isolation plan; get confirmation before execution.

Report offsets and virtual addresses unambiguously, including image base and rebasing assumptions.
