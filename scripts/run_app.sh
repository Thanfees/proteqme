#!/usr/bin/env bash
# ProteqMe launcher — loads Convex secrets from .env.local and runs Flutter
# with the matching --dart-define flags. Pass any extra `flutter run` args.
#
# Examples:
#   ./scripts/run_app.sh                        # uses first connected Android device
#   ./scripts/run_app.sh -d <device-id>         # specific device
#   ./scripts/run_app.sh --release              # release build
#   ./scripts/run_app.sh build apk --release    # build APK instead of run

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env.local"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found." >&2
  echo "  Copy .env.local.example to .env.local and fill in the values." >&2
  exit 1
fi

# Load only the keys we care about, ignore comments and blank lines.
CONVEX_URL=""
CONVEX_DEPLOY_KEY=""
while IFS='=' read -r key value; do
  case "$key" in
    CONVEX_URL)        CONVEX_URL="${value%%#*}" ;;
    CONVEX_DEPLOY_KEY) CONVEX_DEPLOY_KEY="${value%%#*}" ;;
  esac
done < <(grep -E '^[A-Z_]+=' "$ENV_FILE" || true)

# Trim whitespace
CONVEX_URL="$(echo -n "$CONVEX_URL" | xargs)"
CONVEX_DEPLOY_KEY="$(echo -n "$CONVEX_DEPLOY_KEY" | xargs)"

if [[ -z "$CONVEX_URL" || -z "$CONVEX_DEPLOY_KEY" ]]; then
  echo "WARNING: CONVEX_URL or CONVEX_DEPLOY_KEY is empty in .env.local." >&2
  echo "         App will start but Convex-backed features (login, cloud sync) will be disabled." >&2
fi

cd "$ROOT"

# Default to `run` if no flutter subcommand is supplied.
FIRST_ARG="${1:-run}"
case "$FIRST_ARG" in
  run|build|test|drive|attach|analyze|pub)
    SUBCMD="$1"
    shift
    ;;
  *)
    SUBCMD="run"
    ;;
esac

exec flutter "$SUBCMD" \
  --dart-define=CONVEX_URL="$CONVEX_URL" \
  --dart-define=CONVEX_DEPLOY_KEY="$CONVEX_DEPLOY_KEY" \
  "$@"
