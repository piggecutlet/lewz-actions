run_logged() {
  local fn=$1
  local suffix=${2:+_$2}
  local name
  name=$(basename "${GITHUB_WORKFLOW_REF%%@*}" .yml)
  mkdir -p logs
  log="logs/$(TZ=Asia/Tokyo date +%Y/%m/%d/%H%M%S)_${name}${suffix}_${GITHUB_RUN_ID}.log"
  mkdir -p "$(dirname "$log")"
  echo "LOG=$log" >> "$GITHUB_ENV"
  set +e
  ( "$fn" ) > "$log" 2>&1 &
  local pid=$!
  local n=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 10
    n=$((n + 1))
    if [ $((n % 30)) -eq 0 ]; then
      tail -n 30 "$log" | openssl enc -aes-256-cbc -pbkdf2 -salt -pass env:LOG_KEY | base64 -w 1000
      echo
    fi
  done
  wait "$pid"
  local code=$?
  set -e
  openssl enc -aes-256-cbc -pbkdf2 -salt -pass env:LOG_KEY -in "$log" -out "${log%.log}"
  rm "$log"
  git add logs
  git commit -m "logs"
  for i in 1 2 3 4 5; do
    git pull --rebase && git push && break
    sleep $((RANDOM % 20 + 5))
  done
  exit $code
}
