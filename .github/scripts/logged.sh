start_logged() {
  local fn=$1
  local suffix=${2:+_$2}
  local name
  name=$(basename "${GITHUB_WORKFLOW_REF%%@*}" .yml)
  mkdir -p logs
  LOG="logs/$(TZ=Asia/Tokyo date +%Y/%m/%d/%H%M%S)_${name}${suffix}_${GITHUB_RUN_ID}.log"
  mkdir -p "$(dirname "$LOG")"
  echo "LOG=$LOG" >> "$GITHUB_ENV"
  set +e
  ( "$fn" ) >> "$LOG" 2>&1 &
  local pid=$!
  local n=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 10
    n=$((n + 1))
    if [ $((n % 30)) -eq 0 ]; then
      tail -n 30 "$LOG" | openssl enc -aes-256-cbc -pbkdf2 -salt -pass env:LOG_KEY | base64 -w 1000
      echo
    fi
  done
  wait "$pid"
  CODE=$?
  echo "CODE=$CODE" >> "$GITHUB_ENV"
  set -e
}

finish_logged() {
  openssl enc -aes-256-cbc -pbkdf2 -salt -pass env:LOG_KEY -in "$LOG" -out "${LOG%.log}"
  rm "$LOG"
  git add logs
  git commit -m "logs"
  for i in 1 2 3 4 5; do
    git pull --rebase && git push && break
    sleep $((RANDOM % 20 + 5))
  done
  exit "${CODE:-1}"
}

run_logged() {
  start_logged "$@"
  finish_logged
}
