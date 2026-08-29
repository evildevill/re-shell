# re-shell

A Nix flake-based reverse engineering environment designed for use with [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Drop in a binary, capture, or archive and ask Claude to analyze it -- the right tools and context activate automatically.

## Quick start

Make sure `flakes` and `nix-command` experimental features are on. If not, add to your nix config file:

```sh
echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf
```

```sh
# Enter the environment (or use direnv)
nix develop

# Drop a file into the repo root and start Claude Code
cp ~/Downloads/suspicious.exe .
claude

# Then just ask:
#   "Reverse engineer suspicious.exe"
#   "Decompile this APK and find hardcoded API keys"
#   "Analyze this HAR file for undocumented API endpoints"
```

## How it works

The environment bundles a full reverse engineering toolchain (Ghidra, radare2, Frida, mitmproxy, YARA, and more) into a reproducible Nix dev shell. Claude Code is configured via `CLAUDE.md` with discipline-specific **skills** that auto-activate based on file type and context:

| Skill | Activates on | Example files |
|-------|-------------|---------------|
| Windows RE | PE binaries, .NET assemblies, drivers | `.exe`, `.dll`, `.sys` |
| Android RE | Android packages, DEX bytecode | `.apk`, `.xapk` |
| Web RE | HTTP captures, API traffic, protobufs | `.har`, `.proto` |

When Claude detects relevant context, the matching skill loads specialized tool documentation and workflows -- no manual configuration needed.

## Adding tools

The environment is self-modifying. If an analysis needs a tool that isn't installed, Claude can add it:

- **Python packages:** `uv add <pkg>` then `direnv reload`
- **Node.js packages:** `npm install <pkg>` then `direnv reload`
- **System tools:** add to `flake.nix` then `direnv reload`

## Output directories

- **`tmp/`** -- Intermediate work products (gitignored)
- **`artifacts/`** -- Final deliverables like reports and analysis notes (gitignored)
