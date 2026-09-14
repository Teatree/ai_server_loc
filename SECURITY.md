# Security model and verification

This is a private, single-owner application gateway. It is not a multi-user hosting platform.
Render terminates TLS and can see relayed content. A compromised Render account/service can
exercise that connector's allowed app access. Protect GitHub, Render, and Windows accounts with MFA
and keep the machines, browsers, and application dependencies patched.

## Enforced controls

- GitHub OAuth authorization-code flow with state, browser binding, PKCE, and exact callbacks.
- Numeric owner-ID allowlist and verified GitHub two-factor status; no public registration.
- Random opaque sessions held only in server memory, bound to one exact app origin, maximum eight hours.
- Secure HttpOnly host-only session cookies; app cookies cannot overwrite gateway cookies.
- Login/callback rate limits, bounded sessions/states/streams, and authenticated WebSocket handshakes.
- Strict Origin checks on mutations and WebSockets; cross-origin subresources are rejected.
- HTTPS required by environment configuration; no production test-login route or auth bypass.
- Server and connector independently restrict dashboard paths and local-only Windows operations.
- Connector mappings bind each public origin to one app and one locally configured destination.
- No arbitrary URL proxy, shell-execution endpoint, inbound router opening, or app auto-start.
- Gateway credentials and browser sessions are removed before forwarding requests to local apps.
- Native app Authorization headers, cookies, and device/login flows remain separate.
- Uploads/downloads/SSE stream in chunks; HTTP uploads capped at 8 GiB, WebSocket messages at 8 MiB.
- At most 24 simultaneous streams per Render service; no automatic mutation retry or offline queue.
- Sign-out and expiration close that session's active streams. Restart discards all gateway sessions.
- Stopping the local connector cuts remote access without stopping AI services.
- Source dependency versions are pinned; access logging is off to avoid logging app tokens and OAuth codes.
  Render/platform metadata logging is outside this application's control.

## Boundaries to understand

OpenClaw and other apps can exercise their own machine/file/tool permissions after authorization.
Local-only dashboard buttons do not remove an app's independent shell or tool capabilities.
This implementation does not silently change those permissions, authentication settings, or agent policies.
An authorized app session should be treated as access to the capabilities of that app.

The connector cannot protect against a compromised Windows account or malicious local software.
The existing loopback dashboard remains a local trust boundary; it was not exposed directly or modified.
SSH uses the existing private key locally, requires a known host key, and forwards only OpenClaw's port.
Application-specific cookies and native browser storage can persist after gateway logout, but further
requests still require a valid gateway login. Clear site data when using a shared browser.

Each app address has its own session. Sign out at `/_gateway`, or stop the connector to disconnect all.
Credential rotation requires closing existing connections/redeploying the affected service as well as
updating the local token. A Render outage or exhausted free allowance makes remote access unavailable.
An interrupted control request may already have run: inspect state before explicitly retrying it.

## Verification scope

Run `Validate.ps1` locally. Tests use an isolated fake local app and ephemeral loopback gateway;
they do not start, stop, train, generate, or issue real commands on Ubuntu.
The Render build runs the Python mock suite before starting the public service.
Real OAuth/Render handoff and native-app origin/device-pairing checks require post-setup validation.
Passing these tests is not a penetration-test certification or a guarantee against unknown app flaws.
