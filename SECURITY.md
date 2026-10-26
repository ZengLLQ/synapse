# Security Model & Policy

## Reporting Security Issues

Please report vulnerabilities to security@synapse-research.local (or submit a confidential issue).

## Local-First Security Invariants

1. **Loopback Only**: The Julia HTTP API binds strictly to `127.0.0.1`. It never listens on `0.0.0.0` or external network interfaces.
2. **Session Authentication Token**: Every session generates an ephemeral, cryptographically secure 256-bit random authentication token passed via `X-Synapse-Token` header. Requests lacking this token are rejected with `401 Unauthorized`.
3. **Origin Verification**: Incoming requests validate the `Origin` / `Host` headers to prevent DNS rebinding or malicious browser cross-origin requests from attacking the local service.
4. **Path Traversal Protection**: File import and storage operations strictly validate absolute paths against canonical workspace boundaries. Relative path navigation (`../`) is strictly rejected.
5. **Zero Cloud Leakage**: Cloud AI adapters are disabled by default. Network egress is blocked at the adapter dispatch level unless a validated, active `ConsentRecord` is present for that specific provider, purpose, and payload scope.
6. **Untrusted Input Treatment**: All imported document contents, metadata, and model outputs are treated as untrusted strings. Embedded instructions in documents cannot trigger command execution or bypass application security policies.
