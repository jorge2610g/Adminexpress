# Google Play Production auto-sync

## Purpose

Adminexpress now gets the Android Production version from the Google Play Production track. This keeps the stored Production versionCode, verified build, and next build counter aligned after a release is promoted in Play.

## How it works

- `Expressdelivery/.github/workflows/sync-play-production.yml` polls every 15 minutes. The Admin release screen refreshes its displayed state every three minutes while open.
- The workflow uses the existing `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` secret to read the `com.express.usuario1` Production track. It opens a temporary Android Publisher edit to read tracks and deletes it without validating or committing it. It never uploads an AAB or changes a Play release.
- GitHub sends the observed release through the authenticated `android-build-worker`. The worker accepts only the exact repository workflow on `main`; manual dispatch is restricted to the owner.
- Supabase records rollout status. A release advances the Production baseline only when Google Play reports `completed`, and its version, versionCode, signed APK/AAB candidate, and saved QA hashes all match.
- Partial rollouts are shown as observations but do not become the available-to-everyone version. A Play release without a matching signed and QA-certified candidate is recorded but does not advance the gate.

## Updating users

Detection does not itself enable an in-app notice, make an update critical, or send a push. After Play confirms the completed release, open **Distribución de actualizaciones · Producción**, select the detected build, and configure the notice. The normal/critical choice and any user campaign remain explicit Admin actions. Saving an active distribution updates `app_releases`, which the Express app checks on launch and periodically.

## Troubleshooting

If the Admin still shows an older build, check the `Sync Google Play Production` workflow run and the latest Play rollout status. The build remains unchanged if the rollout is still `inProgress`, if Google Play access fails, or if the Play identity does not match a ready, signed candidate with QA evidence. Do not fix this by manually increasing the build counter; resolve the workflow or candidate mismatch first.
