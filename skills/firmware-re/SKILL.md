---
name: firmware-re
description: Analyze embedded firmware, flash dumps, update packages, UF2 files, ESP images, bootloaders, filesystems, signatures, and firmware update mechanisms.
---

# Firmware Reverse Engineering

1. Preserve the original and record SHA-256, size, acquisition source, and known device/model.
2. Identify wrappers and containers with `file`, `exiftool`, hex inspection, vendor metadata, and `binwalk` signatures.
3. Measure entropy by region and distinguish likely compression, encryption, sparse areas, and erased flash.
4. Extract only into `tmp/firmware_<id>/`; record offsets and extraction commands. Treat automatic carving as a hypothesis and validate boundaries.
5. Identify partition tables, filesystems, CPU architecture, load addresses, endianness, boot stages, executables, libraries, device trees, and configuration.
6. Search for update manifests, version checks, rollback controls, public keys, certificate chains, signature verification, hashes, encryption metadata, recovery paths, and debug interfaces.
7. Search extracted content for credentials and tokens, but redact secret values in normal reports.
8. Use `picotool` for RP2 UF2 images, `esptool`/`espsecure` for ESP images, and `objdump` or Ghidra for architecture-appropriate code.
9. Reconstruct the update path as an evidence-linked sequence: discovery, download, validation, staging, activation, rollback, and failure handling.
10. Never flash hardware or modify firmware without explicit confirmation. Put durable reports and requested rules/scripts in `artifacts/<id>/`.
