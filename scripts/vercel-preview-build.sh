#!/usr/bin/env bash
set -euo pipefail

# Isolated Vercel QA build. This does not deploy the canonical Adminexpress site.
FLUTTER_HOME="${TMPDIR:-/tmp}/express-flutter-sdk"
if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  git clone --quiet --depth=1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi
export PATH="$FLUTTER_HOME/bin:$PATH"
export CI=true

flutter --version
flutter pub get
flutter build web --release --base-href /

# Visible proof that this is an isolated QA deployment, not production.
cat > build/web/qa-version.json <<EOF
{
  "app": "Adminexpress Preview QA",
  "mode": "isolated_vercel_preview",
  "git_ref": "${VERCEL_GIT_COMMIT_REF:-unknown}",
  "git_sha": "${VERCEL_GIT_COMMIT_SHA:-unknown}",
  "runtime_environment": "resolved_by_authenticated_account"
}
EOF
