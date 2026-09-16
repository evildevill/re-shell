{
  description = "Agent-neutral reverse engineering environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      treefmt-nix,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      eachSystem =
        f:
        lib.genAttrs (import systems) (
          system:
          f (
            import nixpkgs {
              inherit system;
              config.allowUnfreePredicate =
                pkg:
                builtins.elem (lib.getName pkg) [
                  "volatility3" # License listed as 'unknown' in nixpkgs
                ];
            }
          )
        );

      treefmtEval = eachSystem (
        pkgs:
        treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
        }
      );

      # Load the uv workspace from pyproject.toml + uv.lock
      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

      # Build a package overlay from the workspace lockfile
      overlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };
      perSystem = eachSystem (
        pkgs:
        let
          # Pinned rather than pkgs.python3: uv.lock is resolved against one
          # interpreter version and sourcePreference is "wheel", so the locked
          # wheels only match if the python stays put. Taking the nixpkgs default
          # would break every consumer whose nixpkgs defaults to something else.
          # Bumping this means re-resolving uv.lock for the new version.
          python = pkgs.python313;

          # Build Node.js dependencies from package-lock.json
          nodeModules = pkgs.importNpmLock.buildNodeModules {
            npmRoot = self;
            inherit (pkgs) nodejs;
          };

          # Construct the Python package set from workspace + overlays
          pythonSet =
            (pkgs.callPackage pyproject-nix.build.packages {
              inherit python;
            }).overrideScope
              (
                lib.composeManyExtensions [
                  pyproject-build-systems.overlays.default
                  overlay
                  # Add dependency fixups here as needed, e.g.:
                  # (_final: prev: {
                  #   some-package = prev.some-package.overrideAttrs (old: {
                  #     buildInputs = (old.buildInputs or []) ++ [ pkgs.some-lib ];
                  #   });
                  # })
                ]
              );

          # Build the virtualenv from workspace dependencies
          venv = pythonSet.mkVirtualEnv "re-env" workspace.deps.default;

          # curl-impersonate ships its own copy of curl's wcurl wrapper, which
          # collides with curl when both land in one buildEnv. Drop the duplicate
          # rather than let a priority annotation silently pick a winner.
          curl-impersonate = pkgs.runCommand "curl-impersonate-${pkgs.curl-impersonate.version}" { } ''
            mkdir -p $out
            cp -as ${pkgs.curl-impersonate}/. $out/
            chmod -R u+w $out
            rm -f $out/bin/wcurl $out/share/man/man1/wcurl.1*
          '';

          # A dir-of-symlinks of common wordlists/rules so cracking tools don't
          # require /nix/store spelunking. Linked into $repoRoot/wordlists by the
          # shellHook below. Add more entries here as needed.
          wordlists = pkgs.linkFarm "re-wordlists" [
            {
              name = "rockyou.txt";
              path = "${pkgs.rockyou}/share/wordlists/rockyou.txt";
            }
            {
              # Full SecLists collection (~1.8 GiB closure): Passwords, Discovery,
              # Fuzzing, Usernames, Payloads, etc.
              name = "seclists";
              path = "${pkgs.seclists}/share/wordlists/seclists";
            }
            {
              name = "john-password.lst";
              path = "${pkgs.john}/share/john/password.lst";
            }
            {
              name = "hashcat-rules";
              path = "${pkgs.hashcat}/share/doc/hashcat/rules";
            }
            {
              name = "john-rules";
              path = "${pkgs.john}/share/john/rules";
            }
            {
              # best64.rule ships with john (not this hashcat build); expose it directly
              name = "best64.rule";
              path = "${pkgs.john}/share/john/rules/best64.rule";
            }
          ];
        in
        rec {
          # the toolchain itself, shared by the dev shell and the re-tools package
          tools = [
            venv
            pkgs.uv
            pkgs.nodejs

            # --- General: native binary reverse engineering ---
            pkgs.ghidra # NSA's SRE suite (disassembler + decompiler)
            pkgs.radare2 # UNIX-like RE framework and CLI toolset
            pkgs.rizin # Modern fork of radare2
            pkgs.binwalk # Firmware/binary analysis and extraction

            # --- General: dynamic instrumentation ---
            pkgs.frida-tools # Frida CLI tools (frida, frida-ps, frida-trace, etc.)

            # --- General: static analysis ---
            pkgs.yara # Pattern matching for malware research

            # --- General: network interception & discovery ---
            pkgs.mitmproxy # HTTPS man-in-the-middle proxy
            pkgs.wireshark-cli # Network protocol analyzer (tshark)
            pkgs.nmap # Host/port/service discovery (find a device that moved IP)
            pkgs.avahi # avahi-browse - mDNS/DNS-SD service discovery (IoT devices)

            # --- General: utilities ---
            pkgs.unzip # ZIP extraction
            pkgs.p7zip # 7-Zip archive tool
            # all-targets, not pkgs.binutils: the wrapped build's objdump knows only the
            # host arch, and Ghidra has no Xtensa module at all, so this is the only
            # disassembler here that reads ESP32 firmware. Same 12 binaries, superset.
            pkgs.binutils-unwrapped-all-targets # strings/nm/objdump/readelf, every BFD target
            pkgs.file # File type identification
            pkgs.curl # HTTP client (fetching firmware packages, vendor manifests)
            pkgs.jq # JSON processor
            pkgs.sqlite # SQLite CLI (inspect app databases)
            pkgs.openssl # Certificate and crypto utilities
            pkgs.upx # Universal executable packer/unpacker
            pkgs.unixtools.xxd # Hex dump utility
            pkgs.exiftool # Read/write metadata in files (images, firmware, etc.)
            pkgs.innoextract # Extract Inno Setup installers (common for FW update tools)
            pkgs.asar # Pack/unpack Electron app.asar archives

            # --- General: USB ---
            pkgs.libusb1 # libusb-1.0 backend for pyusb (raw control/bulk transfers)
            pkgs.usbutils # lsusb -v for descriptor dumps, usbhid-dump for HID descriptors

            # --- General: password / hash cracking ---
            pkgs.hashcat # GPU/CPU password recovery
            pkgs.john # John the Ripper (Jumbo) password cracker

            # --- General: FPGA bitstream & netlist analysis ---
            pkgs.trellis # ecpunpack/ecppack: Lattice ECP5 bitstream <-> text config
            pkgs.yosys # Netlist navigation: select cones, submod, techmap, eval, sat
            pkgs.hal-hardware-analyzer # Netlist RE framework (DANA, resynthesis, FSM)

            # --- General: embedded / RP2040-RP2350 (Pico) firmware ---
            pkgs.picotool # Inspect/convert RP2 UF2 firmware, read chip info
            pkgs.pico-sdk # Raspberry Pi Pico SDK (PICO_SDK_PATH set in env)
            pkgs.cmake # Build system for pico-sdk projects
            pkgs.gcc-arm-embedded # arm-none-eabi-gcc cross toolchain

            # --- General: embedded / ESP32 (Espressif) firmware ---
            pkgs.esptool # esptool/espsecure/espefuse: parse ESP32 images, check signatures and eFuses

            # --- Android: APK acquisition ---
            pkgs.apkeep # Download APKs/XAPKs by package name (APKPure, Google Play, F-Droid)

            # --- Android: APK disassembly & manipulation ---
            pkgs.apktool # Decode/rebuild APKs (resources, smali)
            pkgs.apkeditor # APK resource editor
            pkgs.apksigner # Sign and verify APKs
            pkgs.apksigcopier # Copy/extract/patch APK signatures
            pkgs.apkid # Android application identifier (compiler/packer/obfuscator detection)
            pkgs.aapt # Android Asset Packaging Tool
            pkgs.bundletool # Manipulate Android App Bundles (.aab)

            # --- Android: Java/DEX decompilation ---
            pkgs.jadx # Dex-to-Java decompiler (CLI + GUI)
            pkgs.dex2jar # Convert DEX to JAR for Java decompilers
            pkgs.bytecode-viewer # Multi-decompiler bytecode viewer (GUI)

            # --- Android: dynamic instrumentation ---
            pkgs.jnitrace # Frida-based JNI API tracer for Android apps

            # --- Android: static analysis & security scanning ---
            pkgs.trueseeing # Non-decompiling Android vulnerability scanner
            pkgs.quark-engine # Android malware analysis and scoring
            pkgs.koodousfinder # Search and analyze Android apps

            # --- Android: ADB & device interaction ---
            pkgs.android-tools # ADB + fastboot
            pkgs.scrcpy # Display/control Android devices over USB/TCP

            # --- Android: image & OTA tools ---
            pkgs.simg2img # Sparse image to raw image converter
            pkgs.sdat2img # .dat sparse data to ext4 image converter
            pkgs.payload-dumper-go # Extract partitions from Android OTA payloads

            # --- Windows: PE analysis & inspection ---
            pkgs.imhex # Hex editor with pattern language and PE templates

            # --- Windows: .NET decompilation ---
            pkgs.ilspycmd # Decompile .NET assemblies to C# (CLI)
            pkgs.avalonia-ilspy # Cross-platform GUI .NET decompiler

            # --- Windows: string & capability analysis ---
            pkgs.flare-floss # Extract obfuscated/stack/decoded strings from malware

            # --- Windows: memory forensics ---
            pkgs.volatility3 # Analyze Windows memory dumps

            # --- Windows: archive & installer extraction ---
            pkgs.cabextract # Extract Microsoft Cabinet (.cab) archives
            pkgs.innoextract # Extract files from Inno Setup installers
            pkgs.msitools # msiinfo/msiextract - read MSI tables, not just the CAB payload

            # --- Windows: signing & verification ---
            pkgs.osslsigncode # Verify/manipulate Authenticode signatures on PE files

            # --- Windows: running Windows binaries ---
            pkgs.winetricks # Install DLLs/runtimes and tweak Wine prefixes

            # --- Web: protocol buffers & gRPC ---
            pkgs.protobuf # Protobuf compiler (protoc)
            pkgs.protoscope # Inspect raw protobuf wire format without .proto files
            pkgs.grpcurl # CLI client for gRPC services
            pkgs.grpcui # Web UI for interacting with gRPC services

            # --- Web: HTTP & TLS ---
            curl-impersonate # Curl with browser TLS fingerprints
            pkgs.httpie # User-friendly HTTP client

            # --- Web: WebSocket ---
            pkgs.websocat # CLI WebSocket client

            # --- Web: HTML parsing ---
            pkgs.pup # CLI HTML parser (like jq for HTML)
          ]
          ++ lib.optionals pkgs.stdenv.isLinux [
            # Linux-only: need the kernel i2c-dev interface (/dev/i2c-*), not available on Darwin.
            pkgs.v4l-utils # provides edid-decode (parse/validate EDID + CTA/DisplayID exts)
            pkgs.ddcutil # Query/set monitor settings over DDC/CI (VCP codes)
            pkgs.i2c-tools # i2ctransfer/i2cdetect - raw DDC/CI frames (needed for 16-bit VCP codes)
            pkgs.hid-tools # hid-decode/hid-recorder/hid-replay - depends on libevdev (Linux-only)
            pkgs.imgpatchtools # Manipulate Android OTA archives (not packaged for Darwin)
            pkgs.pe-bear # GUI PE viewer for headers, sections, imports, exports (not packaged for Darwin)
            pkgs.detect-it-easy # Identify compilers, packers, protectors (diec) (not packaged for Darwin)
            pkgs.wineWow64Packages.stable # Wine, 64-bit build that also runs 32-bit binaries (no nixpkgs wine variant builds on Darwin)
          ];

          # only meaningful inside the dev shell: a formatter for this repo, and a
          # setup hook rather than a package
          devTools = [
            self.formatter.${pkgs.stdenv.hostPlatform.system}
            pkgs.importNpmLock.hooks.linkNodeModulesHook
          ];

          # environment the tools need wherever they are installed, as opposed to
          # the uv settings below, which only make sense in the dev shell
          envVars = {
            # Ensure Ghidra can find a JDK
            GHIDRA_JAVA_HOME = "${pkgs.jdk}/lib/openjdk";

            # Let pyghidra locate the Ghidra install (pyghidra.start() requires this)
            GHIDRA_INSTALL_DIR = "${pkgs.ghidra}/lib/ghidra";

            # Point pico-sdk builds at the SDK root (contains pico_sdk_init.cmake)
            PICO_SDK_PATH = "${pkgs.pico-sdk}/lib/pico-sdk";

            # pyusb resolves its backend with ctypes.util.find_library, which finds
            # nothing on NixOS. Point it at the libusb-1.0 shared object directly.
            LIBUSB1_SO = "${pkgs.libusb1}/lib/libusb-1.0${pkgs.stdenv.hostPlatform.extensions.sharedLibrary}";
          };

          # one derivation holding the whole toolchain, for installing it somewhere
          # that is not a dev shell
          re-tools = pkgs.buildEnv {
            name = "re-tools";
            paths = tools;
          };

          shell = pkgs.mkShell {
            packages = tools ++ devTools;

            npmDeps = nodeModules;

            env = envVars // {
              # Don't let uv create/sync its own venv -- Nix manages it
              UV_NO_SYNC = "1";

              # Force uv to use the Nix-built Python
              UV_PYTHON = "${venv}/bin/python";

              # Prevent uv from downloading its own Python
              UV_PYTHON_DOWNLOADS = "never";
            };

            shellHook = ''
              unset PYTHONPATH
              if [ -d "$npmDeps/node_modules" ]; then
                linkNodeModulesHook
              fi
              # Expose wordlists/rules as a stable dir-of-symlinks at the repo root
              # so cracking tools don't need /nix/store paths. Symlink, gitignored.
              ln -sfn ${wordlists} "$PWD/wordlists"
              # Ghidra/JPype spill large temp files into java.io.tmpdir. The default
              # /tmp is a small shared tmpfs, and pyghidra crashes there on big
              # programs, so keep the JVM scratch dir repo-local (gitignored).
              mkdir -p "$PWD/tmp/jtmp"
              case "''${_JAVA_OPTIONS-}" in
                *-Djava.io.tmpdir=*) ;; # already set (nested shell, or the user's own choice)
                *) export _JAVA_OPTIONS="-Djava.io.tmpdir=$PWD/tmp/jtmp''${_JAVA_OPTIONS:+ $_JAVA_OPTIONS}" ;;
              esac
              echo "RE environment loaded. See AGENTS.md and skills/ for workflows."
            '';
          };
        }
      );
    in
    {
      devShells = lib.mapAttrs (_: s: { default = s.shell; }) perSystem;

      packages = lib.mapAttrs (_: s: {
        inherit (s) re-tools;
        default = s.re-tools;
      }) perSystem;

      # non-derivation outputs: the environment the toolchain expects
      lib = lib.mapAttrs (_: s: { inherit (s) envVars; }) perSystem;

      formatter = eachSystem (pkgs: treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper);

      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.check self;
      });
    };
}
