# Releasing

```bash
git tag v0.2.0 && git push origin v0.2.0
```

The `Release` workflow then: builds a universal binary, assembles `Jukebox.app`,
signs it with the Developer ID certificate, notarizes and staples it, uploads
`Jukebox-<version>.zip` to a GitHub release, and pushes the new version and
SHA-256 to `Casks/mac-jukebox.rb` in `omniaura/homebrew-tap`.

## Secrets

| Secret | Used for |
|---|---|
| `APPLE_CERTIFICATE_BASE64`, `APPLE_CERTIFICATE_PASSWORD` | Developer ID Application certificate (.p12, base64) |
| `APPLE_ID`, `APPLE_ID_PASSWORD`, `APPLE_TEAM_ID` | Notarization with an app-specific password |
| `APPLE_API_KEY_BASE64`, `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID` | Optional: notarize with an App Store Connect API key instead |
| `HOMEBREW_TAP_DEPLOY_KEY` | SSH private key whose public half is a write deploy key on `omniaura/homebrew-tap` |

Without the signing secrets the workflow still builds, but publishes an
**ad-hoc signed prerelease** and does not touch the tap.
