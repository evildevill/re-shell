# Reverse Engineering Environment

Multi-discipline Nix flake-based development shell for reverse engineering. Enter the environment with `nix develop` or via direnv.

## Skill System

This environment is organized into a **general-purpose core** (this file) and **discipline-specific skills** that auto-activate based on context. Skills provide specialized tool documentation, workflows, and notes for their domain.

### Available Disciplines

| Skill | Path | Activates On |
|-------|------|-------------|
| Android RE | `.claude/skills/android/SKILL.md` | APK, DEX, smali, ADB, Android app analysis |
| Windows RE | `.claude/skills/windows/SKILL.md` | PE, .exe, .dll, .sys, .NET, Windows binary analysis |
| Web RE | `.claude/skills/web/SKILL.md` | Protobuf, gRPC, HAR, HTTP API, WebSocket, TLS fingerprint, web scraping |

### Adding a New Discipline

1. Create `.claude/skills/<discipline>/SKILL.md` with front matter (`name`, `user-invocable: false`, `description` with trigger keywords).
2. Add discipline-specific tools to `flake.nix` under a `# --- <Discipline>:` comment section.
3. Add discipline-specific Python/Node dependencies to `pyproject.toml`/`package.json`.
4. Document the skill in the table above.
5. Tools shared across disciplines stay in the general sections of `flake.nix` and this file.

## Output Directory Convention

All reverse engineering work products must go in one of two locations:

- **`tmp/`** -- Intermediate and throwaway side products: decompiled source, disassembly output, extracted contents, unpacked resources, Ghidra projects, scratch scripts, etc. This directory is in `.gitignore` and will not be committed. Create subdirectories freely (e.g., `tmp/ghidra_project/`, `tmp/extracted_sample/`).
- **`artifacts/<identifier>/`** -- Final, requested deliverables: analysis reports, annotated code snippets, hook scripts, YARA rules, patch files, or anything the user explicitly asks to keep. Use a meaningful identifier as the subdirectory name (e.g., package namespace `com.example.app`, sample hash, malware family name). This directory is also in `.gitignore`: the difference from `tmp/` is durability, not tracking. Work here is meant to survive cleanup of `tmp/` and to be the thing handed back to the user, but it stays local unless the user asks to publish it elsewhere.

When running tools, always direct output into `tmp/` rather than the repo root. Examples:

```sh
ghidra  # save project to tmp/ghidra_<sample>/
r2 -A sample.bin  # any output files go to tmp/
binwalk -e firmware.bin -C tmp/binwalk_firmware/
```

Never leave tool output in the repo root or in ad-hoc directories outside these two locations.

## Environment Structure

The dev shell is defined in `flake.nix` and organized into tool categories. Python dependencies are declared in `pyproject.toml`, locked by `uv.lock`, and built into a Nix virtualenv via [uv2nix](https://github.com/pyproject-nix/uv2nix). Node.js dependencies are declared in `package.json`, locked by `package-lock.json`, and built via `importNpmLock`; bin scripts from npm packages are automatically on PATH. Ghidra's JDK is configured via `GHIDRA_JAVA_HOME`.

## Installed Tools (General-Purpose)

Discipline-specific tools are documented in their respective skill files. The tools below are available across all RE disciplines.

### Native Binary Reverse Engineering

| Tool | Command | Description |
|------|---------|-------------|
| Ghidra | `ghidra` | NSA's software reverse engineering suite with decompiler; supports x86, x64, ARM, ARM64, MIPS, and more |
| radare2 | `r2 binary` | CLI-first RE framework for disassembly, analysis, patching, and debugging |
| rizin | `rizin binary` | Modern radare2 fork with improved APIs and Ghidra decompiler integration via rz-ghidra |
| binwalk | `binwalk firmware.bin` | Scan and extract embedded files, compressed streams, and filesystems from binaries |

### Dynamic Instrumentation

| Tool | Command | Description |
|------|---------|-------------|
| frida-tools | `frida -p <pid> -l script.js` | Inject JavaScript into running processes for runtime hooking |
| frida-tools | `frida-ps` | List running processes (add `-U` for USB device, `-R` for remote) |
| frida-tools | `frida-trace -p <pid> -i "open*"` | Auto-generate handler stubs for traced functions |

### Static Analysis

| Tool | Command | Description |
|------|---------|-------------|
| YARA | `yara rules.yar target/` | Match file patterns using YARA rules for malware identification |

### Display / Monitor Firmware

| Tool | Command | Description |
|------|---------|-------------|
| edid-decode | `edid-decode slot.bin` | Parse and validate EDID base blocks plus CTA-861 / DisplayID extensions |
| ddcutil | `ddcutil capabilities` / `ddcutil getvcp 0x60` | Query and set monitor settings over DDC/CI (VCP codes); requires a real attached display |
| i2c-tools | `i2ctransfer -y N w5@0x37 ...` | Raw I2C frames; needed for 16-bit/vendor DDC/CI opcodes ddcutil won't emit |

Both need the `i2c-dev` kernel module loaded (`sudo modprobe i2c-dev`) and RW access to
`/dev/i2c-*`. On NixOS, `hardware.i2c.enable = true;` loads it and grants the `i2c` group access.

### USB

| Tool | Command | Description |
|------|---------|-------------|
| usbutils | `lsusb -v -d 2e1a:` | Dump USB descriptors (configs, interfaces, endpoints) |
| usbutils | `usbhid-dump -d 2e1a:` | Dump raw HID report descriptors straight from the device |
| hid-tools | `hid-decode /sys/class/hidraw/hidraw0/device/report_descriptor` | Decode a HID report descriptor into named usages and report layouts |
| hid-tools | `hid-recorder /dev/hidraw0` | Record live HID reports (descriptor plus timestamped traffic) |
| hid-tools | `hid-replay recording.hid` | Replay a recording through a virtual uhid device |

A vendor device often exposes several `/dev/hidraw*` nodes. Pick the one whose report
descriptor starts with a vendor-defined usage page (`06 XX ff`); `hid-decode` names it for you.
Reading and writing hidraw needs permission on the node: run as root, or add a udev rule such as
`SUBSYSTEM=="hidraw", ATTRS{idVendor}=="14ed", ATTRS{idProduct}=="1012", MODE="0660", GROUP="users"`.
Plain `open()` plus `select()` on the hidraw node is enough for feature-free report I/O; no
extra Python binding is needed.

Raw USB from Python uses `pyusb` over the libusb-1.0 backend. `ctypes.util.find_library`
finds nothing on NixOS, so the dev shell exports `LIBUSB1_SO`; pass it explicitly:

```python
import os, usb.core, usb.backend.libusb1 as lb
be = lb.get_backend(find_library=lambda _: os.environ["LIBUSB1_SO"])
dev = usb.core.find(idVendor=0x1234, idProduct=0x5678, backend=be)
```

Control and bulk transfers need write access to `/dev/bus/usb/*`: run as root, or add a
udev rule for the target VID:PID. Note that a vendor device often changes VID:PID when it
switches USB modes, so match on all of the identities it can present.

### Password / Hash Cracking

Wordlists and rules are exposed as a stable dir-of-symlinks at `wordlists/` in the repo root (gitignored, points into the Nix store) so no `/nix/store` spelunking is needed. Contents: `wordlists/rockyou.txt`, `wordlists/seclists/` (full SecLists tree), `wordlists/best64.rule`, `wordlists/hashcat-rules/`, `wordlists/john-rules/`, `wordlists/john-password.lst`. To add more, edit the `wordlists` linkFarm in `flake.nix`.

| Tool | Command | Description |
|------|---------|-------------|
| hashcat | `hashcat -m 0 -a 0 hash.txt wordlists/rockyou.txt -r wordlists/best64.rule` | GPU/CPU password recovery |
| john | `john --wordlist=wordlists/rockyou.txt hash.txt` | John the Ripper (Jumbo); also bundles `*2john` converters (e.g. `zip2john`) |

### FPGA Bitstream Analysis

| Tool | Command | Description |
|------|---------|-------------|
| Project Trellis | `ecpunpack in.bit out.config` | Unpack a Lattice ECP5 bitstream into a text config naming every tile, routing arc, and config word (handles compressed bitstreams) |
| Project Trellis | `ecppack in.config out.bit` | Repack a text config into a bitstream |
| Project Trellis | `ecpbram`, `ecppll` | Patch block-RAM contents; compute PLL parameters |
| yosys | `yosys -p "read_verilog nl.v; ..."` | Netlist navigation: `select` cones (`%cie` stops at FFs = one pipeline stage), `submod`, `techmap`, `eval`, `sat` |
| HAL | `hal` (pkg `hal-hardware-analyzer`) | Netlist RE framework: DANA register grouping, `resynthesis`, `netlist_preprocessing`, `solve_fsm` |

The text config gives resource usage, I/O standards, and primitive modes without
any netlist work. I/O standards are the fastest route to identifying external
interfaces: SSTL15 implies DDR3, and the absence of differential inputs proves a
part cannot receive TMDS. Note that the config carries block-RAM *settings*
(`WID`, `CSDECODE`) but not block-RAM *contents*.

**Never count instances by counting `enum:` lines** -- one block RAM or pin spans
several tiles and each repeats the setting (gives 116 BRAMs on a 56-BRAM part).
Count real hardware via the `pytrellis` routing graph instead. `pytrellis` is
built for one specific Python version and needs *its own* database, or it fails
with `RuntimeError: No such node`; its maps iterate as keys, not pairs.

HAL needs structural Verilog plus a gate library (no BLIF/JSON frontend) and
ships no Lattice library. Its `module_identification` plugin -- the one that finds
adders and constant multipliers -- supports iCE40 and Xilinx only. yosys
`fsm_detect`/`fsm_extract`/`memory_collect` produce *zero* output on a flattened
netlist. Use `sat` as a fast falsifier, not a prover: refuting a wrong constant
takes under a second, proving the right one may not finish.

### Embedded / RP2040-RP2350 (Pico) Firmware

| Tool | Command | Description |
|------|---------|-------------|
| picotool | `picotool info -a firmware.uf2` | Inspect/convert RP2 UF2 firmware, read binary info and chip details |
| pico-sdk | (via `PICO_SDK_PATH`) | Raspberry Pi Pico SDK; `PICO_SDK_PATH` is set automatically in the dev shell |
| cmake | `cmake -B build` | Build system for pico-sdk projects |
| gcc-arm-embedded | `arm-none-eabi-gcc` | ARM cross toolchain (`arm-none-eabi-{gcc,objcopy,gdb,...}`) |

### Embedded / ESP32 (Espressif) Firmware

esptool is v5, whose subcommands are hyphenated (`image-info`, not the v4
`image_info`); most guides online still show the v4 spelling.

| Tool | Command | Description |
|------|---------|-------------|
| esptool | `esptool image-info app.bin` | Parse an ESP32 image: chip target, entry point, segment table, SHA-256 and checksum, plus the app description (version string, IDF version, compile date) |
| esptool | `esptool --chip esp32 elf2image app.elf` | Convert an ELF into the flashable image format; `image-info` reads it back |
| espsecure | `espsecure signature-info-v2 app.bin` | Read an appended secure-boot v2 signature block without needing the key |
| espsecure | `espsecure verify-signature -v 2 -k pub.pem app.bin` | Verify a secure-boot signature against a public key |
| espefuse | `espefuse --port /dev/ttyUSB0 summary` | Read the eFuse block: secure boot and flash encryption state, key readout protection |

`image-info`, `elf2image` and both `espsecure` commands above are pure file
operations. Only `espefuse` and flash access need hardware in download mode.

Xtensa is the reason `binutils-unwrapped-all-targets` is in the shell. ESP32 and
ESP32-S2/S3 are Xtensa LX6/LX7, which Ghidra cannot disassemble at all, and only
the ESP32-C and -H parts are RISC-V. Disassemble a raw flash dump with
`objdump -D -b binary -m xtensa`, and check `objdump --info` for the target list.

### Network Interception and Discovery

| Tool | Command | Description |
|------|---------|-------------|
| mitmproxy | `mitmproxy` / `mitmweb` / `mitmdump` | Intercept, inspect, and modify HTTPS traffic |
| tshark | `tshark -i any -f "host 10.0.0.1"` | Capture and analyze network packets (Wireshark CLI) |
| nmap | `nmap -p 9123 --open 10.42.0.0/22` | Host, port, and service discovery |
| avahi | `avahi-browse -rt _elg._tcp` | Browse mDNS/DNS-SD services and resolve them to address and port |

Find a network device before you scan for it. Most consumer hardware advertises
itself over mDNS, so `avahi-browse -art` names the device and its port in one
step. Use `nmap` when the device does not advertise, or when the service name is
unknown. `avahi-browse` needs the avahi daemon on the host
(`services.avahi.enable = true;` on NixOS).

### General Utilities

`unzip`, `7z` (p7zip), `file`, `curl`, `jq`, `sqlite3`, `openssl` -- standard tools for archive extraction, file identification, HTTP fetching, JSON processing, database inspection, and certificate handling.

| Tool | Command | Description |
|------|---------|-------------|
| UPX | `upx -d packed.exe` | Decompress executables packed with UPX |
| xxd | `xxd binary` | Hex dump / reverse hex dump utility |
| binutils | `strings -n 8 file`, `nm`, `objdump`, `readelf` | Read strings, symbols, and ELF structure. Built `--enable-targets=all`, so `objdump -m` reaches Xtensa, RISC-V, MIPS and AVR, not just the host arch |
| exiftool | `exiftool file` | Read/write embedded metadata (images, documents, firmware) |
| innoextract | `innoextract -e -d out setup.exe` | Extract Inno Setup installers (common packaging for vendor firmware update tools) |
| asar | `asar extract app.asar tmp/app/` | Unpack Electron `app.asar` archives (`asar list` to inspect first) |
| uv | `uv add <pkg>` | Python package manager; add dependencies to pyproject.toml and uv.lock, then `direnv reload` to rebuild |
| npm | `npm install <pkg>` | Node.js package manager; add dependencies to package.json and package-lock.json, then `direnv reload` to rebuild |

### Python Scripting Environment

Python dependencies are managed via `pyproject.toml` and `uv.lock`, built into a Nix virtualenv by uv2nix. The following general-purpose libraries are pre-installed:

| Library | Import | Description |
|---------|--------|-------------|
| frida | `import frida` | Python API for Frida dynamic instrumentation |
| pyghidra | `import pyghidra` | Python API for Ghidra; run headless analysis, access the decompiler, and script Ghidra entirely from Python via JPype |
| yara-python | `import yara` | Compile and apply YARA rules from Python |
| IPython | `ipython` | Enhanced interactive Python shell for exploratory analysis |
| NumPy | `import numpy` | Array/numeric computing (byte-array math, entropy, correlation) |
| SciPy | `import scipy` | Scientific computing (FFT, signal processing, optimization) |
| Pillow | `from PIL import Image` | Image loading/manipulation (extracted textures, QR, framebuffers) |
| pyusb | `import usb.core` | Raw USB control/bulk/interrupt transfers (see [USB](#usb) for the libusb backend) |
| capstone | `import capstone` | Disassembler for x86, x64, ARM, ARM64, MIPS, and more; disassemble a few bytes without a Ghidra run |
| cryptography | `from cryptography.hazmat.primitives.asymmetric...` | Signature and cipher primitives (Ed25519, ECDSA, RSA, AES) for firmware signature checks |

Use `capstone` for a quick look at a small number of instructions, for example to
identify a patch site or to read a function prologue. Ghidra gives better results
on a full image, but a large blob can need more than an hour to analyze.

Discipline-specific Python libraries are listed in their respective skill files. To add a Python package permanently, run `uv add <package>` then `direnv reload`. See [Augmenting the Environment](#augmenting-the-environment).

### Node.js Scripting Environment

Node.js dependencies are managed via `package.json` and `package-lock.json`, built into a Nix-managed `node_modules` by `importNpmLock`. Bin scripts from installed packages are automatically available on PATH via `linkNodeModulesHook`.

Discipline-specific Node.js tools are listed in their respective skill files. To add a Node.js package permanently, run `npm install <package>` then `direnv reload`. See [Augmenting the Environment](#augmenting-the-environment). Note that npm packages with native install scripts that download binaries (e.g., the `frida` npm package) will fail in the Nix sandbox -- use nixpkgs equivalents for those.

## Common Workflows

### Binary analysis with Ghidra

```sh
# GUI (requires display server on headless/WSL)
ghidra  # import binary, save project to tmp/

# Headless analysis
ghidra-analyzeHeadless tmp/ghidra_project ProjectName -import binary -postScript script.java
```

### Scripted Ghidra analysis with pyghidra

`pyghidra.start()` requires `GHIDRA_INSTALL_DIR` to point at the Ghidra install. The dev shell sets this automatically (along with `GHIDRA_JAVA_HOME`), so `import pyghidra; pyghidra.start()` works directly -- no manual `export GHIDRA_INSTALL_DIR=...` prefix needed.

The shell also exports `_JAVA_OPTIONS=-Djava.io.tmpdir=$PWD/tmp/jtmp`, which moves JVM scratch
files off the shared `/tmp` tmpfs. Without it, `pyghidra.start()` fails on large programs. Every
`java` process prints a `Picked up _JAVA_OPTIONS:` line to stderr as a result; ignore it.

One thing the shell cannot set for you: raise the Python recursion limit **before**
`pyghidra.start()`, or JPype's type construction hits the default limit and aborts.

```python
import sys
sys.setrecursionlimit(100000)

import pyghidra

# Start the Ghidra JVM (once per session)
pyghidra.start()

# Open a binary, auto-analyze, and access the Flat API
with pyghidra.open_program("binary", project_location="tmp/ghidra_project") as flat_api:
    program = flat_api.getCurrentProgram()
    listing = program.getListing()
    # iterate functions, read decompiled code, etc.

# Or run a Ghidra script (.java/.py) against a binary
pyghidra.run_script("binary", "script.java", project_location="tmp/ghidra_project")
```

### Quick CLI disassembly

```sh
# radare2
r2 -A binary
# rizin
rizin -A binary
```

### Network traffic interception

```sh
# Start mitmproxy, configure target to use proxy
mitmproxy --listen-port 8080

# Or capture raw packets
tshark -i any -w tmp/capture.pcap
```

### Adding Python packages with uv

Python dependencies are managed through `pyproject.toml` and built natively by Nix via uv2nix. To add a package:

```sh
# Add a dependency (updates pyproject.toml and uv.lock)
uv add protobuf

# Rebuild the Nix environment with the new dependency
direnv reload
```

For temporary/one-off usage without modifying the project, use `uv run`:

```sh
# Run a one-off script with a dependency not in the environment
uv run --with cryptography script.py

# Start a REPL with extra packages available
uv run --with pycryptodome ipython
```

### Adding Node.js packages with npm

Node.js dependencies are managed through `package.json` and built natively by Nix via `importNpmLock`. To add a package:

```sh
# Add a dependency (updates package.json and package-lock.json)
npm install some-tool

# Rebuild the Nix environment with the new dependency
direnv reload
```

Bin scripts from installed packages are automatically available on PATH (e.g., installing a package that provides a CLI tool makes it directly runnable).

For temporary/one-off usage without modifying the project, use `npx`:

```sh
# Run a one-off tool without installing
npx some-tool@latest
```

## Augmenting the Environment

When a task calls for a tool or library not currently in the dev shell, you have several options:

### Temporary: ad-hoc install

- **Python**: `uv run --with <pkg>` for one-off exploration. See [uv workflow above](#adding-python-packages-with-uv).
- **Node.js**: `npx <pkg>` for one-off CLI tools. See [npm workflow above](#adding-nodejs-packages-with-npm).

### Permanent: add to the environment

**For Python libraries**, use uv to add them to `pyproject.toml`:

1. Run `uv add <package>` (updates `pyproject.toml` and `uv.lock`).
2. Run `direnv reload` to rebuild the Nix virtualenv with the new dependency.
3. If the package needs native libraries or build fixups, add overrides to the `dependencyFixups` section in `flake.nix`. See comments there for examples.
4. **Update the appropriate skill file or `CLAUDE.md`** to document the new library.

**For Node.js packages**, use npm to add them to `package.json`:

1. Run `npm install <package>` (updates `package.json` and `package-lock.json`).
2. Run `direnv reload` to rebuild the Nix node_modules with the new dependency.
3. **Update the appropriate skill file or `CLAUDE.md`** to document the new tool.

**For non-Python/non-Node tools**, add them to `flake.nix`:

1. **Search nixpkgs** for the package using the `/nix-package-search` skill (e.g., `/nix-package-search protobuf`).
2. **Edit `flake.nix`** to add the package to the `packages` list under the appropriate category section.
3. **Reload the environment** by running `direnv reload` (or exiting and re-entering `nix develop`).
4. **Update the appropriate skill file or `CLAUDE.md`** to document the new tool so documentation stays in sync with the flake.

You are encouraged to self-modify `flake.nix`, `pyproject.toml`, `package.json`, skill files, and this file whenever the analysis requires a tool that should be part of the standard environment. Keep the existing organizational structure (category comments, table format) when adding entries.

**Important:** When documenting a new tool, verify that the actual binary name on PATH matches what you write in the Command column. Nix package names often differ from binary names (e.g., `pkgs.aapt` provides `aapt2`, `pkgs.avalonia-ilspy` provides `ILSpy`, `pkgs.ghidra` wraps binaries with a `ghidra-` prefix). Run `which <command>` or check the package's `bin/` directory after `direnv reload` to confirm before documenting.

## Notes

- Ghidra requires a display server for its GUI. On headless/WSL systems, use an X server (e.g., VcXsrv) or Ghidra's headless analyzer: `ghidra-analyzeHeadless`.
- Frida requires a matching `frida-server` binary running on the target (device or host).
