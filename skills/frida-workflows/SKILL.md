---
name: frida-workflows
description: Perform authorized Frida instrumentation, tracing, runtime observation, Java or native hooks, and reproducible hook-script development.
---

# Frida Workflows

Use this skill only on processes and devices the user is authorized to inspect.

1. Confirm target, platform, architecture, Frida client/server compatibility, and whether spawn or attach is appropriate.
2. Start with process/module enumeration and narrow observation hooks. Avoid changing behavior unless the user explicitly requests it.
3. Log timestamps, thread IDs, arguments, return values, backtraces, and module-relative addresses when useful; redact secrets by default.
4. Guard hooks against null pointers, overload ambiguity, recursion, and unloaded modules. Use module-relative offsets rather than unstable absolute addresses.
5. Save scratch hooks beneath `tmp/` and requested reusable scripts beneath `artifacts/<id>/` with usage notes and tested versions.
6. For Android Java hooks, wait for the Java runtime and resolve overloads explicitly. For native hooks, validate ABI and pointer sizes.
7. Do not use runtime hooks to bypass access controls, steal credentials, or conceal malicious behavior.
