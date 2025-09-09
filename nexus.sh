#!/usr/bin/env bash
set -euo pipefail

# =========================
# Config cơ bản
# =========================
BASE_DIR="${HOME}/nexus_nodes"       # Thư mục chứa tất cả node
SCREEN_PREFIX="nexus_node"           # Tiền tố tên screen
LOG_NAME="nexus.log"                 # Tên file log trong mỗi node HOME

# Liệt kê NODE-ID ngay trong script (nếu muốn)
NODE_IDS=( )

# Hoặc đọc từ file (mỗi dòng 1 node-id)
IDS_FILE="./id.txt"

# Tuỳ chọn: thêm flags riêng cho từng node (nếu Nexus CLI hỗ trợ)
declare -A EXTRA_FLAGS
# Ví dụ:
# EXTRA_FLAGS["36063968"]="--port 47001"
# EXTRA_FLAGS["36063969"]="--port 47002"
# EXTRA_FLAGS["36063970"]="--port 47003"

# =========================
# Helpers
# =========================
red()   { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
cyan()  { printf "\033[36m%s\033[0m\n" "$*"; }

ensure_deps() {
  command -v screen >/dev/null 2>&1 || { red "Thiếu 'screen'. Cài: sudo apt update && sudo apt install -y screen"; exit 1; }
  command -v nexus-network >/dev/null 2>&1 || { red "Thiếu 'nexus-network'. Cài: curl https://cli.nexus.xyz/ | sh && source ~/.bashrc"; exit 1; }
}

load_ids() {
  if ((${#NODE_IDS[@]}==0)); then
    if [[ -f "$IDS_FILE" ]]; then
      # Chuẩn hoá: bỏ CRLF, tách theo dòng, bỏ rỗng
      mapfile -t NODE_IDS < <(tr -d '\r' < "$IDS_FILE" | sed 's/^[ \t]*//;s/[ \t]*$//' | sed '/^$/d')
    fi
  fi
  if ((${#NODE_IDS[@]}==0)); then
    red "Chưa có NODE-ID. Hãy điền vào mảng NODE_IDS trong script hoặc tạo file $IDS_FILE (mỗi dòng 1 id)."
    exit 1
  fi
}

start_one() {
  local node_id="$1"
  local node_home="${BASE_DIR}/${node_id}"
  local session="${SCREEN_PREFIX}_${node_id}"

  # Nếu screen đã tồn tại → bỏ qua
  if screen -ls | grep -q "[.]${session}[[:space:]]"; then
    cyan "Bỏ qua '${node_id}' vì screen '${session}' đã chạy."
    return 0
  fi

  mkdir -p "$node_home"

  local flags=""
  if [[ -n "${EXTRA_FLAGS[$node_id]:-}" ]]; then
    flags="${EXTRA_FLAGS[$node_id]}"
  fi

  local run_cmd="export HOME='${node_home}';
echo \"[INFO] HOME=\$HOME\";
echo \"[INFO] Starting node-id=${node_id}\";
nexus-network start --node-id '${node_id}' ${flags} 2>&1 | tee -a '${node_home}/${LOG_NAME}'"

  screen -S "$session" -dm bash -lc "$run_cmd"
  green "Đã start node '${node_id}' trong screen '${session}'. Log: ${node_home}/${LOG_NAME}"
}

start_all() {
  ensure_deps
  load_ids
  mkdir -p "$BASE_DIR"
  for id in "${NODE_IDS[@]}"; do
    start_one "$id"
  done
  cyan "Tổng số node đã start: ${#NODE_IDS[@]}"
  echo
  echo "📜 Liệt kê screen: screen -ls"
  echo "🔎 Xem log 1 node: tail -f ${BASE_DIR}/<node-id>/${LOG_NAME}"
  echo "🧷 Gắn vào screen: screen -r ${SCREEN_PREFIX}_<node-id>"
  echo "❌ Dừng 1 node:    screen -S ${SCREEN_PREFIX}_<node-id> -X quit"
}

stop_one() {
  local node_id="$1"
  local session="${SCREEN_PREFIX}_${node_id}"
  screen -S "$session" -X quit || true
  green "Đã dừng screen '${session}' (nếu đang chạy)."
}

stop_all() {
  load_ids
  for id in "${NODE_IDS[@]}"; do
    stop_one "$id"
  done
}

status() {
  screen -ls || true
}

usage() {
  cat <<EOF
Usage: $0 <command>

Commands:
  start       Start toàn bộ node trong NODE_IDS hoặc id.txt
  stop        Stop toàn bộ node
  status      Xem danh sách screen
  start-one   <node-id>  Start đơn lẻ 1 node
  stop-one    <node-id>  Stop đơn lẻ 1 node
EOF
}

# =========================
# Main
# =========================
cmd="${1:-}"
case "$cmd" in
  start)     start_all ;;
  stop)      stop_all ;;
  status)    status ;;
  start-one) id="${2:-}"; [[ -z "$id" ]] && { red "Thiếu <node-id>"; exit 1; }; ensure_deps; start_one "$id" ;;
  stop-one)  id="${2:-}"; [[ -z "$id" ]] && { red "Thiếu <node-id>"; exit 1; }; stop_one "$id" ;;
  *)         usage; exit 1 ;;
esac
