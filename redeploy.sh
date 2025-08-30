#!/usr/bin/env bash
set -euo pipefail

# ---------- config (tweak as you like) ----------
DEFAULT_LOG_LINES=60
# -----------------------------------------------

die(){ echo "ERROR: $*" >&2; exit 1; }
msg(){ printf "\n>>> %s\n" "$*"; }
confirm(){ [[ "${AUTO_YES:-0}" == "1" ]] && return 0; read -r -p "$1 [y/N] " a; [[ "$a" =~ ^[Yy]$ ]]; }

usage(){
  cat <<'EOF'
Usage: ./redeploy.sh [-s service] [-l LINES] [-y] [-h]

Options:
  -s service   Only build/up a specific docker compose service (default: all)
  -l LINES     Tail LINES of logs after start (default: 60)
  -y           Non-interactive (assume "yes" to prompts)
  -h           Help

Interactive actions (you will be prompted):
  1) Redeploy (use build cache)
  2) Redeploy (no cache)
  3) Fetch+Pull from origin, then Redeploy (use cache)
  4) Fetch+Pull from origin, then Redeploy (no cache)
EOF
}

SERVICE=""
TAIL_LINES="$DEFAULT_LOG_LINES"
AUTO_YES=0
while getopts ":s:l:yh" opt; do
  case "$opt" in
    s) SERVICE="$OPTARG" ;;
    l) TAIL_LINES="$OPTARG" ;;
    y) AUTO_YES=1 ;;
    h) usage; exit 0 ;;
    \?) usage; exit 1 ;;
  esac
done

# ---------- sanity checks ----------
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not inside a git repo."
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

COMPOSE_FILE=""
for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  [[ -f "$f" ]] && COMPOSE_FILE="$f" && break
done
[[ -n "$COMPOSE_FILE" ]] || die "No docker compose file found in repo root."

# ---------- repo info ----------
REPO_NAME="$(basename "$REPO_ROOT")"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
ORIGIN_URL="$(git remote get-url origin 2>/dev/null || echo 'origin not set')"

msg "Repository : $REPO_NAME"
msg "Branch     : $BRANCH"
msg "Remote     : $ORIGIN_URL"
msg "Compose    : $COMPOSE_FILE"

# ---------- service detection (optional) ----------
list_services(){ docker compose -f "$COMPOSE_FILE" config --services; }
if [[ -z "$SERVICE" ]]; then
  SERVICES=($(list_services))
  if (( ${#SERVICES[@]} == 0 )); then
    die "No services found in compose."
  elif (( ${#SERVICES[@]} == 1 )); then
    SERVICE="${SERVICES[0]}"
    msg "Detected single service: $SERVICE"
  else
    msg "Multiple services detected: ${SERVICES[*]}"
    echo "Leave blank to build all, or type a service name to target just one."
    read -r -p "Service to build (empty = all): " SERVICE_INPUT || true
    SERVICE="${SERVICE_INPUT:-}"
    if [[ -n "$SERVICE" ]] && ! printf '%s\n' "${SERVICES[@]}" | grep -qx "$SERVICE"; then
      die "Service '$SERVICE' not in compose. Available: ${SERVICES[*]}"
    fi
  fi
fi

# ---------- functions ----------
git_update(){
  msg "Fetching + fast-forward pulling origin/$BRANCH…"
  git fetch --all --prune
  git pull --ff-only origin "$BRANCH"
}

compose_down(){
  msg "Stopping containers…"
  docker compose -f "$COMPOSE_FILE" down
}

compose_build(){
  local nocache="$1"
  local target="$SERVICE"
  local cache_flag=()
  [[ "$nocache" == "1" ]] && cache_flag=(--no-cache)
  if [[ -n "$target" ]]; then
    msg "Building service '$target' ${cache_flag:+(no cache)}…"
    docker compose -f "$COMPOSE_FILE" build "${cache_flag[@]}" "$target"
  else
    msg "Building ALL services ${cache_flag:+(no cache)}…"
    docker compose -f "$COMPOSE_FILE" build "${cache_flag[@]}"
  fi
}

compose_up(){
  local target="$SERVICE"
  msg "Starting containers…"
  if [[ -n "$target" ]]; then
    docker compose -f "$COMPOSE_FILE" up -d "$target"
  else
    docker compose -f "$COMPOSE_FILE" up -d
  fi
}

show_logs(){
  # Try to infer containers; if service was specified, limit logs to that service
  msg "Recent logs (tail $TAIL_LINES):"
  if [[ -n "$SERVICE" ]]; then
    docker compose -f "$COMPOSE_FILE" logs -f --tail "$TAIL_LINES" "$SERVICE" &
    sleep 2; pkill -P $$ -f "docker compose .* logs" || true
  else
    docker compose -f "$COMPOSE_FILE" logs -f --tail "$TAIL_LINES" &
    sleep 2; pkill -P $$ -f "docker compose .* logs" || true
  fi
  docker compose -f "$COMPOSE_FILE" ps
}

# ---------- menu ----------
echo
echo "Select action:"
echo "  1) Redeploy (use build cache)"
echo "  2) Redeploy (no cache)"
echo "  3) Fetch+Pull, then Redeploy (use cache)"
echo "  4) Fetch+Pull, then Redeploy (no cache)"
read -r -p "Choice [1-4]: " CHOICE

case "$CHOICE" in
  1) DO_PULL=0; NO_CACHE=0 ;;
  2) DO_PULL=0; NO_CACHE=1 ;;
  3) DO_PULL=1; NO_CACHE=0 ;;
  4) DO_PULL=1; NO_CACHE=1 ;;
  *) die "Invalid choice." ;;
esac

echo
msg "Summary:"
echo "  Repo    : $REPO_NAME"
echo "  Branch  : $BRANCH"
echo "  Service : ${SERVICE:-ALL}"
echo "  Pull    : $([[ "$DO_PULL" == "1" ]] && echo yes || echo no)"
echo "  NoCache : $([[ "$NO_CACHE" == "1" ]] && echo yes || echo no)"
confirm "Proceed?" || die "Aborted."

# ---------- execute ----------
[[ "$DO_PULL" == "1" ]] && git_update
compose_down
compose_build "$NO_CACHE"
compose_up
show_logs

msg "Done."
