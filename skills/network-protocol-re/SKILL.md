---
name: network-protocol-re
description: Analyze PCAP, PCAPNG, USB captures, serial logs, WebSocket streams, and unknown network protocols to infer framing, state, fields, and message semantics.
---

# Network and Protocol Reverse Engineering

Work from captures supplied or authorized by the user. Do not probe third-party hosts without permission.

1. Hash and preserve captures; record capture point, timestamps, interfaces, filters, and known participants.
2. Summarize endpoints, transports, ports, conversations, timing, retransmissions, TLS metadata, DNS, and discovery traffic with `tshark`.
3. Export streams into `tmp/` and separate framing from payload semantics.
4. Infer length fields, type codes, sequence numbers, checksums, encoding, compression, encryption, request/response pairs, and state transitions by comparing multiple messages.
5. Use known plaintext and controlled input changes when available. Label every inferred field with confidence and supporting packet/frame numbers.
6. For protobuf/gRPC, WebSocket, HAR, and HTTP traffic, also use `web-re`.
7. Produce a message table, state diagram when useful, open questions, and a minimal safe decoder or dissector only when requested.

Never present decryption or field meaning as confirmed without reproducible evidence.
