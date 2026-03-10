# Decision: Decouple CI Keychain Password from Match Secret

**Date:** 2026-03-09  
**Author:** Dallas (iOS Dev)  
**Status:** Implemented  
**Commit:** `fix: decouple CI keychain password from match secret in TestFlight workflow`

## Problem

The TestFlight CI workflow (`.github/workflows/testflight-beta.yml`) used `secrets.MATCH_PASSWORD` for two unrelated purposes:
1. As the ephemeral CI keychain password (create/unlock/partition-list)
2. As the fastlane match passphrase to decrypt certificates from the match git repo

When `MATCH_PASSWORD` was deleted from GitHub Secrets, the workflow broke at the keychain setup step — before it even reached the match decryption step.

## Decision

Decouple the CI keychain password from the match secret:
- **CI keychain:** Use a hardcoded temp password (`"ci-keychain-temp-password"`) since the keychain is ephemeral — created at the start of the run and destroyed in the cleanup step. No security risk.
- **Match decryption:** Continue using `secrets.MATCH_PASSWORD` exclusively for `fastlane match --keychain_password` (the encryption passphrase for the certificates repo).

## Rationale

- The CI keychain is a throwaway artifact — it exists only for the duration of the build and is deleted in the `Cleanup keychain` step (`security delete-keychain`).
- Using a secret for throwaway infrastructure adds unnecessary coupling and failure modes.
- This eliminates one dependency on `secrets.MATCH_PASSWORD`, making the workflow more resilient.

## Required Secrets (documented in workflow header)

| Secret | Purpose |
|--------|---------|
| `MATCH_PASSWORD` | Passphrase for fastlane match certificate decryption |
| `MATCH_GIT_URL` | URL of the private certificates repo |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Base64-encoded `username:token` for cert repo access |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect API issuer ID |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | .p8 private key content (raw or base64) |
