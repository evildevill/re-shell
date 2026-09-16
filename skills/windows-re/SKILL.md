---
name: windows-re
description: Windows reverse engineering tools and workflows. Auto-activates when context involves PE files, .exe, .dll, .sys, .NET assemblies, Windows drivers, Windows malware, x86/x64 Windows binaries, or Windows-specific analysis.
---

# Windows Reverse Engineering

This skill covers Windows-specific RE tools available in the dev shell. For shared tools and artifact conventions, use `skills/general-re/SKILL.md`.

## PE Analysis & Inspection

| Tool | Command | Description |
|------|---------|-------------|
| PE-bear | `PE-bear binary.exe` | GUI PE viewer for headers, sections, imports, exports, resources, and overlays |
| Detect It Easy | `diec binary.exe` | Identify compilers, packers, protectors, and linkers used to build a PE |
| ImHex | `imhex binary.exe` | Hex editor with pattern language, data inspector, and PE structure templates |

## .NET Decompilation

| Tool | Command | Description |
|------|---------|-------------|
| ILSpyCmd | `ilspycmd -p -o tmp/src/ assembly.dll` | Decompile .NET assemblies to C# source (CLI) |
| Avalonia ILSpy | `ILSpy` | Cross-platform GUI .NET decompiler (ILSpy port) |

## String & Capability Analysis

| Tool | Command | Description |
|------|---------|-------------|
| FLARE-FLOSS | `floss binary.exe` | Extract obfuscated strings, stack strings, and decoded strings from malware |

## Memory Forensics

| Tool | Command | Description |
|------|---------|-------------|
| Volatility 3 | `vol -f memory.dmp windows.pslist` | Analyze Windows memory dumps for processes, DLLs, registry, network, and more |
| Volatility 3 | `vol -f memory.dmp windows.malfind` | Detect injected code and suspicious memory regions |
| Volatility 3 | `vol -f memory.dmp windows.dlllist` | List loaded DLLs for each process |

## Archive & Installer Extraction

| Tool | Command | Description |
|------|---------|-------------|
| cabextract | `cabextract archive.cab` | Extract Microsoft Cabinet (.cab) archives |
| innoextract | `innoextract setup.exe` | Extract files from Inno Setup installers without running them |
| msitools | `msiextract -C tmp/msi/ installer.msi` | Extract an MSI payload with the installed file names |
| msitools | `msiinfo tables installer.msi` / `msiinfo export installer.msi Property` | Read the MSI database tables |

`7z x installer.msi` also extracts an MSI, but it gives you the internal stream
names, which vendors frequently mangle (`filUrdi_4VOhmE74tO5C.L675ZenTA`).
`msiextract` applies the `File` and `Directory` tables and writes the real names
and the real tree. Use `msiinfo export` to read `Property` for the version and
the product code, and `CustomAction` for the code the installer runs.

## Running Windows Binaries

| Tool | Command | Description |
|------|---------|-------------|
| Wine | `WINEPREFIX=$PWD/tmp/wineprefix wine setup.exe` | Run Windows executables on Linux (32- and 64-bit) |
| Wine | `wineboot -u` / `winecfg -v win11` | Create or update a prefix; set the reported Windows version |
| Wine | `wine reg add <key> /v <name> /d <value> /f` | Edit the registry of a prefix without a GUI |
| winetricks | `winetricks vcrun2019 dotnet48` | Install redistributables and runtimes into a prefix |

Always point `WINEPREFIX` at a directory under `tmp/`, one prefix per target, so a failed
install is a `rm -rf` away and never touches `~/.wine`. `WINEDEBUG=-all` silences the noise.

## Authenticode & Code Signing

| Tool | Command | Description |
|------|---------|-------------|
| osslsigncode | `osslsigncode verify binary.exe` | Verify, extract, or manipulate Authenticode signatures on PE files |

## Windows Python Libraries

| Library | Import | Description |
|---------|--------|-------------|
| pefile | `import pefile` | Parse and manipulate PE files: headers, sections, imports, exports, resources |
| dnfile | `import dnfile` | Parse .NET PE files: metadata tables, streams, type references |
| lief | `import lief` | Multi-format binary parser (PE, ELF, Mach-O) with modification support |
| unicorn | `import unicorn` | CPU emulator framework for binary emulation (x86, ARM, MIPS, etc.) |
| oletools | `import oletools` | Analyze OLE/Office files for macros, VBA, and embedded objects |

## Workflows

### PE static analysis

```sh
# Identify compiler/packer/protector
diec binary.exe

# Inspect PE structure
PE-bear binary.exe  # GUI
# or from Python:
python3 -c "import pefile; pe = pefile.PE('binary.exe'); pe.print_info()"

# Extract obfuscated strings
floss binary.exe > tmp/floss_output.txt

# Check YARA rules
yara rules.yar binary.exe
```

### .NET assembly analysis

```sh
# Decompile to C# source
ilspycmd -p -o tmp/ilspy_assembly/ assembly.dll

# Or use the GUI decompiler
ILSpy  # open assembly.dll

# Inspect .NET metadata from Python
python3 -c "import dnfile; dn = dnfile.dnPE('assembly.dll'); print(dn.net.metadata)"
```

### Unpacking with UPX

```sh
# Detect packing
diec packed.exe

# Decompress UPX-packed binary
upx -d packed.exe -o tmp/unpacked.exe

# Verify unpacking
diec tmp/unpacked.exe
```

### Unpacking a vendor installer under Wine

Carving an installer overlay gives you the file data but not the file names. Running the
installer in a throwaway prefix gives a correct tree, and it is usually faster:

```sh
export WINEPREFIX=$PWD/tmp/wineprefix WINEDEBUG=-all
wineboot -u && winecfg -v win11
wine setup.exe --mode unattended --unattendedmodeui none --eula_choice eula_accepted
find $WINEPREFIX/drive_c -maxdepth 4 -iname '*<product>*'
```

The `--mode unattended` flags are the BitRock/InstallBuilder ones; NSIS uses `/S` and Inno
Setup uses `/VERYSILENT` (prefer `innoextract` for Inno). Identify BitRock by the string
`::bitrock_tcl_is_using_only_s32_dll_path` in `.text`.

Installers that gate on the OS version read the registry rather than trusting `winecfg`.
Wine's `win11` mode still reports build 22000, so a Windows 11 only installer needs:

```sh
wine reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion' /v CurrentBuild       /d 26100 /f
wine reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion' /v CurrentBuildNumber /d 26100 /f
```

For an Electron product, unpack the payload and recover the original sources if the build
shipped its webpack source maps:

```sh
asar extract "$WINEPREFIX/drive_c/Program Files/<Vendor>/<App>/resources/app.asar" tmp/app/
python3 -c "
import json, pathlib
m = json.load(open('tmp/app/main.js.map'))
for name, src in zip(m['sources'], m['sourcesContent']):
    p = pathlib.Path('tmp/app_src') / name.lstrip('./')
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(src or '')
"
```

`sourcesContent` holds the pre-minification TypeScript verbatim, including any endpoints and
credentials the vendor compiled into the app config.

### Windows malware triage

```sh
# Identify build tools and protections
diec sample.exe

# Extract strings (including obfuscated)
floss sample.exe > tmp/strings.txt

# Scan with YARA
yara malware_rules.yar sample.exe

# Parse PE structure
python3 -c "
import pefile
pe = pefile.PE('sample.exe')
for entry in pe.DIRECTORY_ENTRY_IMPORT:
    print(entry.dll.decode())
    for imp in entry.imports:
        print(f'  {imp.name.decode() if imp.name else imp.ordinal}')
"

# Check for suspicious OLE content (if Office doc)
python3 -c "from oletools.olevba import VBA_Parser; vba = VBA_Parser('doc.xlsm'); vba.analyze_macros()"
```

### Memory forensics

```sh
# List processes
vol -f memory.dmp windows.pslist

# Detect code injection
vol -f memory.dmp windows.malfind

# Dump suspicious process
vol -f memory.dmp windows.pslist --pid 1234 --dump -o tmp/procdump/

# List network connections
vol -f memory.dmp windows.netscan
```

### Binary emulation with Unicorn

```python
from unicorn import *
from unicorn.x86_const import *

# Emulate x86 code snippet
mu = Uc(UC_ARCH_X86, UC_MODE_32)
mu.mem_map(0x1000, 0x1000)
mu.mem_write(0x1000, code_bytes)
mu.reg_write(UC_X86_REG_ESP, 0x2000)
mu.emu_start(0x1000, 0x1000 + len(code_bytes))
```

## Notes

- PE-bear, Avalonia ILSpy, and ImHex require a display server for their GUIs. On headless/WSL systems, use an X server (e.g., VcXsrv) or use CLI alternatives (`diec`, `ilspycmd`, Python libraries).
- `retdec` (RetDec decompiler) is not currently installed but is available in nixpkgs (`pkgs.retdec`). It consumes significant memory; use Ghidra's decompiler for most analysis.
- Volatility 3 plugins are under the `windows.` namespace for Windows memory analysis. Use `vol --help` to list all available plugins.
- `oletools` provides both Python APIs and CLI entry points (`olevba`, `oleid`, `rtfobj`, etc.) for analyzing Office/OLE documents.
- `unicorn` is general-purpose but particularly useful for Windows x86/x64 shellcode and malware analysis. `capstone` is documented in `skills/general-re/SKILL.md` with the other general-purpose Python libraries.
