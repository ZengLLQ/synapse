# ADR 0003: Loopback-Bound Authenticated Local REST API

## Status
Accepted

## Context
The Tauri desktop shell and React frontend need a high-performance, secure communication channel with the Julia engine. Exposing local ports without authentication poses serious security risks (e.g. malicious web pages triggering CSRF attacks against localhost).

## Decision
We implemented a local REST API using **`HTTP.jl`**, bound strictly to **`127.0.0.1`**, protected by an ephemeral per-session token (`X-Synapse-Token`) and strict `Origin` header validation.

## Rationale
- Binding strictly to `127.0.0.1` prevents access from the LAN.
- Generating a random 256-bit token on startup and requiring it in all HTTP requests eliminates unauthorized cross-origin requests from web browsers.
- Validating the `Origin` header against `tauri://localhost`, `http://localhost`, or `http://127.0.0.1` prevents DNS rebinding exploits.
- Standard HTTP/JSON enables clear request/response validation, straightforward debugging, and simple integration with React.

## Consequences
- Desktop frontend must retrieve the session token from Tauri upon initialization and include it in all HTTP requests.
