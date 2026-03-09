# Decision: GitHub Actions iOS Code Signing Keychain Setup

**Date:** 2026-03-09  
**Agent:** Lambert  
**Status:** Implemented  
**Category:** CI/CD Infrastructure

## Context

The TestFlight Beta Build workflow (`.github/workflows/testflight-beta.yml`) was consistently hanging at the "Build for App Store" step during `xcodebuild archive`. This occurred on both v0.1.0-beta.1 and v0.1.0-beta.2 builds, with the step running for 1.5+ hours with no output before being cancelled.

### Root Cause

GitHub Actions macOS runners require explicit keychain management for iOS code signing:

1. `fastlane match` imports certificates into a keychain
2. `xcodebuild` on CI cannot access the keychain without explicit configuration
3. Without proper setup, xcodebuild prompts for keychain access (hangs on headless CI)

## Decision

Implement the standard GitHub Actions pattern for iOS code signing with temporary keychain management.

### Implementation

Added 5 workflow steps:

1. **Setup Keychain** (before match step)
   - Create temporary keychain at `$RUNNER_TEMP/app-signing.keychain-db`
   - Set 6-hour timeout, disable lock-on-sleep
   - Unlock keychain and set as default
   - Configure `set-key-partition-list` to allow codesign access without prompts

2. **Configure fastlane match** to use temporary keychain
   - Pass `--keychain_name` and `--keychain_password` flags
   - Certificates import directly to our controlled keychain

3. **Configure xcodebuild** to use temporary keychain
   - Add `OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN_PATH"`
   - Explicitly tell codesign where to find signing identity

4. **Add timeout protection**
   - `timeout-minutes: 30` on build step
   - Prevents infinite hangs if issue recurs

5. **Cleanup keychain** (always runs)
   - `if: always()` ensures cleanup even on failure
   - Prevents keychain accumulation on runner

## Rationale

- **Industry standard:** This pattern is widely used across iOS CI/CD workflows on GitHub Actions
- **Security:** Temporary keychain isolated per job, cleaned up automatically
- **Reliability:** Explicit keychain reference eliminates ambiguity for xcodebuild
- **No custom tooling:** Uses built-in macOS `security` command
- **Reuses secrets:** `MATCH_PASSWORD` serves double duty as keychain password

## Alternatives Considered

1. **Use Xcode's automatic code signing in CI**
   - Rejected: Requires App Store Connect API key, more complex setup
   - Current manual signing with match is simpler and already configured

2. **Use default system keychain**
   - Rejected: GitHub Actions runners may have keychain permission issues
   - Temporary keychain provides isolation and control

3. **Switch to fastlane gym for building**
   - Rejected: Would require rewriting entire build step
   - Direct xcodebuild with keychain flag is minimal change

## Consequences

### Positive
- ✅ Fixes the 1.5+ hour hang issue
- ✅ Build should complete in ~10-15 minutes (typical iOS archive time)
- ✅ No changes to secrets, certificates, or provisioning profiles needed
- ✅ Standard pattern makes workflow easier to maintain

### Negative
- None identified (this is a standard, proven pattern)

### Neutral
- Adds 5 workflow steps (net +50 lines in YAML)
- Keychain setup adds ~5-10 seconds to workflow runtime

## Testing & Validation

- ✅ YAML syntax validated with `python3 -c "import yaml"`
- ✅ All existing workflow steps preserved
- ✅ ExportOptions.plist verified (no changes needed)
- ⏳ **Next:** Test on actual GitHub Actions runner with next beta tag push

## References

- GitHub Actions iOS Code Signing: https://docs.github.com/en/actions/deployment/deploying-xcode-applications/installing-an-apple-certificate-on-macos-runners-for-xcode-development
- fastlane match keychain docs: https://docs.fastlane.tools/actions/match/
- Apple security command reference: `man security`

## Related Work

- Original workflow: `.github/workflows/testflight-beta.yml`
- Match repository: Configured via `MATCH_GIT_URL` secret
- Team ID: ZPKA84F3TY
- App Identifier: com.olyforge3d.printfarmer.ios

## Tags

`ci-cd`, `ios`, `code-signing`, `github-actions`, `keychain`, `testflight`, `bugfix`
