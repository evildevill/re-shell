---
name: web-re
description: Web reverse engineering tools and workflows. Auto-activates when context involves protobuf, gRPC, HAR files, HTTP API analysis, WebSocket, web scraping, TLS fingerprinting, curl-impersonate, or web protocol reverse engineering.
---

# Web Reverse Engineering

This skill covers web-specific RE tools available in the dev shell. For shared tools and artifact conventions, use `skills/general-re/SKILL.md`.

## Protocol Buffers & gRPC

| Tool | Command | Description |
|------|---------|-------------|
| protoc | `protoc --decode_raw < message.bin` | Compile .proto files and decode protobuf messages |
| protoscope | `protoscope < message.bin` | Inspect raw protobuf wire format without .proto definitions |
| grpcurl | `grpcurl -plaintext localhost:50051 list` | CLI client for gRPC services with reflection support |
| grpcui | `grpcui -plaintext localhost:50051` | Web UI for interacting with gRPC services |

## HTTP & TLS

| Tool | Command | Description |
|------|---------|-------------|
| curl-impersonate | `curl_chrome142 https://example.com` | Curl with browser TLS fingerprints to bypass bot detection |
| httpie | `http GET https://api.example.com/endpoint` | User-friendly HTTP client for API exploration |

## WebSocket

| Tool | Command | Description |
|------|---------|-------------|
| websocat | `websocat ws://localhost:8080/ws` | CLI WebSocket client for bidirectional communication |

## HTML Parsing

| Tool | Command | Description |
|------|---------|-------------|
| pup | `cat page.html \| pup 'div.content text{}'` | CLI HTML parser (like jq for HTML); uses CSS selectors |

## Web Python Libraries

| Library | Import | Description |
|---------|--------|-------------|
| protobuf | `from google.protobuf import descriptor_pb2` | Python protobuf runtime for parsing and generating messages |
| grpcio | `import grpc` | gRPC Python client for interacting with gRPC services |
| grpcio-tools | `from grpc_tools import protoc` | protoc plugin for Python gRPC code generation |
| beautifulsoup4 | `from bs4 import BeautifulSoup` | HTML/XML parsing for web scraping and response analysis |
| haralyzer | `from haralyzer import HarParser` | Parse and analyze HAR (HTTP Archive) files |

## Workflows

### Decode unknown protobuf messages

```sh
# Inspect raw wire format (no .proto needed)
protoscope < message.bin

# Decode with protoc (raw mode, no .proto needed)
protoc --decode_raw < message.bin
```

### Decode protobuf with .proto definitions

```sh
# Compile .proto to Python
protoc --python_out=tmp/ schema.proto

# Decode a specific message type
protoc --decode=MyMessage schema.proto < message.bin
```

### Explore gRPC services

```sh
# List available services (requires server reflection)
grpcurl -plaintext localhost:50051 list

# Describe a service
grpcurl -plaintext localhost:50051 describe my.Service

# Call an RPC method
grpcurl -plaintext -d '{"field": "value"}' localhost:50051 my.Service/Method

# Interactive web UI
grpcui -plaintext localhost:50051
```

### Analyze HAR files

```python
import json
from haralyzer import HarParser

with open("traffic.har") as f:
    har = HarParser(json.load(f))

for page in har.pages:
    print(f"Page: {page.title}")
    print(f"  Entries: {len(page.entries)}")
    print(f"  Total size: {page.page_size}")

# Inspect individual entries
for entry in har.pages[0].entries:
    print(f"{entry.request.method} {entry.request.url} -> {entry.response.status}")
```

### curl-impersonate for bot-protected APIs

```sh
# Impersonate Chrome's TLS fingerprint
curl_chrome142 -H "Accept: application/json" https://api.example.com/data

# Impersonate Firefox
curl_firefox144 https://example.com

# Use with mitmproxy for inspection
curl_chrome142 --proxy http://127.0.0.1:8080 https://api.example.com/data

# Generic wrapper (auto-selects a browser profile)
curl-impersonate https://example.com
```

### WebSocket interception

```sh
# Connect to a WebSocket endpoint
websocat ws://localhost:8080/ws

# Pipe data through (stdin -> WS, WS -> stdout)
echo '{"type":"subscribe","channel":"events"}' | websocat ws://localhost:8080/ws

# Use with mitmproxy for WS interception
# mitmproxy supports WebSocket natively; configure target to use proxy
```

### HTML scraping and analysis

```sh
# Extract all links from a page
curl -s https://example.com | pup 'a attr{href}'

# Extract specific content by CSS selector
curl -s https://example.com | pup 'div.main-content text{}'

# From Python with BeautifulSoup
python3 -c "
from bs4 import BeautifulSoup
import urllib.request
html = urllib.request.urlopen('https://example.com').read()
soup = BeautifulSoup(html, 'html.parser')
for link in soup.find_all('a'):
    print(link.get('href'))
"
```

## Notes

- mitmproxy can export HAR files: use `mitmdump -w tmp/traffic.har --set hardump=tmp/traffic.har` or the mitmweb UI export.
- curl-impersonate provides browser-specific binaries named by browser version (e.g., `curl_chrome142`, `curl_firefox144`, `curl_safari260`). The generic `curl-impersonate` wrapper auto-selects a profile. Run `ls $(dirname $(which curl-impersonate))` to see all available profiles.
- grpcui requires a display server (opens a browser). On headless/WSL, use grpcurl for CLI access or forward the port.
- `blackboxprotobuf` is excluded from the environment because it hard-pins `protobuf==3.10.0`, which is incompatible with modern grpcio-tools. Use `protoscope` or `protoc --decode_raw` for schema-less protobuf decoding instead.
