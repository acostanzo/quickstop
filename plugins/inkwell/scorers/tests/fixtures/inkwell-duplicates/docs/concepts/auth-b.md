---
title: Authentication
updated: 2026-05-05
template: concept
---

# Authentication

Signed JWTs with rotating refresh tokens. Sessions verify on each
request via a short-lived access token and a longer-lived refresh
token. The middleware verifies the JWT signature and the expiry
claim. When verification fails the request is rejected with a 401
response and the refresh token cookie is cleared from the client.

## Related

- [auth-a.md](auth-a.md)
