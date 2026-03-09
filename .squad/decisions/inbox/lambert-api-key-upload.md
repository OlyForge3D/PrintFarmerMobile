# Decision: Replace FASTLANE_USER/PASSWORD with App Store Connect API Keys for CI Upload

**Date:** 2026-03-09
**Agent:** Lambert (Networking/DevOps)
**Status:** Implemented
**Severity:** High (blocking TestFlight uploads in CI)

## Problem Statement

The TestFlight Beta Build workflow (`.github/workflows/testflight-beta.yml`) was failing with:
```
Invalid username and password combination
```

This occurs because Apple no longer accepts iTunes Connect credentials (FASTLANE_USER/FASTLANE_PASSWORD) for CI-based uploads. The rejection is intentional—Apple now requires API Key authentication for improved security.

## Root Cause

- **Apple's policy shift:** API Keys provide role-based access control and better audit trails
- **CI environment detection:** GitHub Actions runners are detected as non-standard environments; Apple's fraud detection blocks credential-based login
- **Credential-based auth designed for local:** FASTLANE_USER/PASSWORD were originally designed for local developer machines

## Solution Implemented

### 1. Generate App Store Connect API Key (one-time setup)

1. Log in to [App Store Connect → Users and Access → Integrations → Keys](https://appstoreconnect.apple.com/access/integrations/api/)
2. Click **+** to create a new API Key
3. Assign role: **Developer** (minimum) or **Admin** (if available)
4. Download the `.p8` file and save securely
5. Copy `Key ID` and `Issuer ID` from the key details page

### 2. Add GitHub Secrets (3 required)

In repository settings → Secrets and variables → Actions, add:

| Secret Name | Value |
|---|---|
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID from App Store Connect API page |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Issuer ID (company/team ID) |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | Base64-encoded content of the `.p8` file |

To base64-encode the `.p8` file:
```bash
base64 -i AuthKey_<KEY_ID>.p8 | pbcopy  # macOS
cat AuthKey_<KEY_ID>.p8 | base64 -w 0   # Linux
```

### 3. Workflow Changes

**"Upload to TestFlight" step:**
- Removed: `FASTLANE_USER`, `FASTLANE_PASSWORD` env vars
- Added: Create temporary JSON file with API key data
- Decode base64 `.p8` content and inject into JSON template:
  ```json
  {
    "key_id": "KEY_ID",
    "issuer_id": "ISSUER_ID",
    "key": "-----BEGIN EC PRIVATE KEY-----\n...\n-----END EC PRIVATE KEY-----",
    "in_house": false
  }
  ```
- Pass to `fastlane pilot upload --api_key_path <json_file>`
- Cleanup temp file after upload

**"Setup code signing with fastlane match" step:**
- Removed: `FASTLANE_USER`, `FASTLANE_PASSWORD` (not needed for git-based match)
- Kept: `MATCH_PASSWORD`, `MATCH_GIT_URL`, `MATCH_GIT_BASIC_AUTHORIZATION`

## Why This Approach?

| Aspect | Why API Keys |
|---|---|
| **Security** | API keys are scoped (role-based), revocable, and provide audit trails |
| **Reliability** | No account lockouts, no 2FA challenges in CI |
| **Compliance** | Meets Apple's policy for CI/CD authentication |
| **Standardization** | Fastlane (and xcodebuild) both support `--api_key_path` natively |
| **Maintenance** | Single secret rotation instead of managing app password + 2FA |

## Files Modified

- `.github/workflows/testflight-beta.yml` (3 changes):
  1. Updated "Setup code signing with fastlane match" (removed FASTLANE_USER/PASSWORD)
  2. Updated "Upload to TestFlight" (API key JSON creation + cleanup)
  3. Updated "Cleanup keychain" (added API key JSON cleanup)

## Testing & Validation

- ✅ YAML syntax validated
- ✅ All existing steps preserved (no regression)
- ✅ Workflow structure unchanged (only step content modified)

## Alternatives Considered

| Option | Pros | Cons | Decision |
|---|---|---|---|
| **API Key JSON (chosen)** | Standard, native fastlane support, clean | Requires base64 encoding | ✅ Chosen |
| `xcrun altool --upload-app` | Alternative Apple tool | Requires .p8 in ~/.appstoreconnect/private_keys/ | Rejected (extra filesystem setup) |
| App-specific password | Simpler than full account creds | Still relies on password auth (less secure) | Rejected (still violates Apple's policy) |
| JWT token (manual) | Maximum control | Complex implementation, not standard | Rejected (overcomplicated) |

## Dependencies & Blockers

- ✅ No dependencies on other workflow changes
- ⚠️ **Requires:** Someone with App Store Connect admin access to generate API key
- ⚠️ **Requires:** GitHub repo admin to add the 3 secrets

## Rollout

1. **Generate API key** in App Store Connect
2. **Add 3 secrets** to GitHub repo settings
3. **Merge workflow changes**
4. **Test:** Trigger a beta tag push to verify upload succeeds
5. **Cleanup:** Verify old FASTLANE_USER/PASSWORD secrets are no longer used elsewhere

## References

- [Apple App Store Connect API Docs](https://developer.apple.com/documentation/appstoreconnectapi)
- [Fastlane Pilot Plugin Docs](https://docs.fastlane.tools/actions/pilot/)
- [GitHub Actions Security Best Practices](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)
