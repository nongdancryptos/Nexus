#!/usr/bin/env bash
set -euo pipefail

# =========================
# Config cơ bản
# =========================
BASE_DIR="${HOME}/nexus_nodes"       # Thư mục chứa tất cả node
SCREEN_PREFIX="nexus_node"           # Tiền tố tên screen
LOG_NAME="nexus.log"                 # Tên file log trong mỗi node HOME
PORT_BASE=47000                      # Nếu CLI có flags port, bạn có thể dùng dãy này (tùy chọn)

# Cách 1: LIỆT KÊ NODE-ID NGAY TẠI ĐÂY
# Điền node-id của bạn vào mảng dưới (mỗi phần tử là một node):
NODE_IDS=(
  # "node-id-1"
  # "node-id-2"
  # "node-id-3"
)

# Cách 2: Đọc từ file node_ids.txt (mỗi dòng 1 node-id) nếu mảng trống
IDS_FILE="./node_ids.txt"

# Tuỳ chọn: thêm flags riêng cho từng node (nếu Nexus CLI hỗ trợ).
# Ví dụ: --port, --rpc-port, ...
# Nếu không chắc chắn CLI có, hãy để trống để an toàn.
declare -A EXTRA_FLAGS
# Ví dụ:
# EXTRA_FLAGS["node-id-1"]="--port 47001 --rpc-port 8501"
# EXTRA_FLAGS["node-id-2"]="--port 47002 --rpc-port 8502"

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
      mapfile -t NODE_IDS < <(grep -v '^\s*$' "$IDS_FILE")
    fi
  fi
  if ((${#NODE_IDS[@]}==0)); then
    red "Chưa có NODE-ID. Hãy điền vào mảng NODE_IDS trong script hoặc tạo file $IDS_FILE (mỗi dòng 1 id)."
    exit 1
  fi
}

start_one() {
  local node_id="$1"
  local idx="$2"
  local node_home="${BASE_DIR}/${node_id}"
  local session="${SCREEN_PREFIX}_${node_id}"

  mkdir -p "$node_home"

  # Ghép flags bổ sung nếu có (port, rpc-port, v.v.)
  local flags=""
  if [[ -n "${EXTRA_FLAGS[$node_id]:-}" ]]; then
    flags="${EXTRA_FLAGS[$node_id]}"
  fi

  # Lệnh chạy trong screen: đặt HOME riêng cho node này
  local run_cmd="export HOME='${node_home}';
echo \"[INFO] HOME=\$HOME\"; 
echo \"[INFO] Starting node-id=${node_id}\";
nexus-network start --node-id '${node_id}' ${flags} 2>&1 | tee -a '${node_home}/${LOG_NAME}'"

  # Tạo/khởi động phiên screen
  screen -S "$session" -dm bash -lc "$run_cmd"

  green "Đã start node '${node_id}' trong screen '${session}'. Log: ${node_home}/${LOG_NAME}"
}

start_all() {
  ensure_deps
  load_ids
  mkdir -p "$BASE_DIR"
  local i=0
  for id in "${NODE_IDS[@]}"; do
    start_one "$id" "$i"
    ((i++))
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
  start       Start toàn bộ node trong NODE_IDS hoặc node_ids.txt
  stop        Stop toàn bộ node
  status      Xem danh sách screen
  start-one   <node-id>  Start đơn lẻ 1 node
  stop-one    <node-id>  Stop đơn lẻ 1 node

Gợi ý:
  - Điền NODE_IDS ngay trong script hoặc tạo file node_ids.txt (mỗi dòng 1 node-id).
  - Mỗi node có HOME riêng: ${BASE_DIR}/<node-id>
  - Log của node:          ${BASE_DIR}/<node-id>/${LOG_NAME}
  - Tên screen:            ${SCREEN_PREFIX}_<node-id>
EOF
}

# =========================
# Main
# =========================
cmd="${1:-}"
case "$cmd" in
  start)
    start_all
    ;;
  stop)
    stop_all
    ;;
  status)
    status
    ;;
  start-one)
    id="${2:-}"; [[ -z "$id" ]] && { red "Thiếu <node-id>"; exit 1; }
    ensure_deps
    start_one "$id" 0
    ;;
  stop-one)
    id="${2:-}"; [[ -z "$id" ]] && { red "Thiếu <node-id>"; exit 1; }
    stop_one "$id"
    ;;
  *)
    usage
    exit 1
    ;;
esac
