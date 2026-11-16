#!/usr/bin/env bash
# LineFlow Quick Start / Runner Script
# Usage:
#   ./run.sh          # Start or verify all services
#   ./run.sh status   # Check current service status
#   ./run.sh stop     # Stop services
#   ./run.sh restart  # Restart all services

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="${1:-start}"

is_port_in_use() {
  local port="$1"
  lsof -i :"$port" -sTCP:LISTEN >/dev/null 2>&1 || ss -tulpn | grep -q ":$port "
}

check_status() {
  echo "=========================================================="
  echo "              LineFlow Service Status                     "
  echo "=========================================================="

  # Emulator (Port 9000)
  if is_port_in_use 9000; then
    echo "  [✓] Firebase Emulator  : RUNNING on http://127.0.0.1:9000"
  else
    echo "  [✗] Firebase Emulator  : STOPPED (Port 9000)"
  fi

  # Backend (Port 4000)
  if is_port_in_use 4000; then
    local health
    health=$(curl -s --max-time 2 http://localhost:4000/api/v1/health || true)
    if [[ "$health" == *"ok"* ]]; then
      echo "  [✓] Backend API        : RUNNING on http://localhost:4000 (Healthy)"
    else
      echo "  [!] Backend API        : RUNNING on port 4000 (Health check failed)"
    fi
  else
    echo "  [✗] Backend API        : STOPPED (Port 4000)"
  fi

  # Frontend (Port 5173)
  if is_port_in_use 5173; then
    echo "  [✓] Frontend Web App   : RUNNING on http://localhost:5173"
  else
    echo "  [✗] Frontend Web App   : STOPPED (Port 5173)"
  fi

  echo "=========================================================="
  echo "  Direct Links:"
  echo "    • Student/Customer Token Page : http://localhost:5173/take"
  echo "    • Public Queue / Home         : http://localhost:5173"
  echo "    • Live TV Display Board       : http://localhost:5173/display"
  echo "    • Admin Portal                : http://localhost:5173/admin/login"
  echo "        Credentials: admin / adminpassword123"
  echo "    • Staff Portal                : http://localhost:5173/staff/login"
  echo "    • Staff Kiosk (PIN)           : http://localhost:5173/kiosk"
  echo "    • Token Lookup                : http://localhost:5173/lookup"
  echo "=========================================================="
}

stop_services() {
  echo "Stopping services on ports 5173, 4000..."
  fuser -k 5173/tcp >/dev/null 2>&1 || true
  fuser -k 4000/tcp >/dev/null 2>&1 || true
  echo "Backend and Frontend stopped."
}

start_services() {
  # 1. Firebase Emulator
  if ! is_port_in_use 9000; then
    echo "Starting Firebase Emulator (Port 9000)..."
    cd "$ROOT_DIR/firebase" && npx firebase-tools emulators:start --only database >/dev/null 2>&1 &
    sleep 3
  fi

  # 2. Backend
  if ! is_port_in_use 4000; then
    echo "Starting Backend API (Port 4000)..."
    cd "$ROOT_DIR/backend" && npm run dev >/dev/null 2>&1 &
    local tries=0
    while ! is_port_in_use 4000 && [ $tries -lt 10 ]; do
      sleep 1
      tries=$((tries + 1))
    done
  fi

  # 3. Frontend
  if ! is_port_in_use 5173; then
    echo "Starting Frontend Web App (Port 5173)..."
    cd "$ROOT_DIR/frontend" && npm run dev >/dev/null 2>&1 &
    local tries=0
    while ! is_port_in_use 5173 && [ $tries -lt 10 ]; do
      sleep 1
      tries=$((tries + 1))
    done
  fi

  check_status
}

case "$ACTION" in
  stop)
    stop_services
    ;;
  restart)
    stop_services
    sleep 1
    start_services
    ;;
  status)
    check_status
    ;;
  start|*)
    start_services
    ;;
esac
