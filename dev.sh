#!/usr/bin/env bash
# Pemakaian:  ./dev.sh up      nyalakan database + backend + panel admin
#             ./dev.sh phone   sambungkan HP (adb reverse) lalu jalankan app Flutter
#             ./dev.sh watch   pasang ulang jalur HP -> backend otomatis tiap kabel dicolok ulang (biarkan jalan)
#             ./dev.sh photos <folder> [--apply]   unggah foto produk massal (nama berkas = nama produk; tanpa --apply hanya dry-run)
#             ./dev.sh down    matikan backend + panel
#             ./dev.sh status  cek apa yang sedang hidup
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
ADB="$HOME/Android/Sdk/platform-tools/adb"
export PATH="$HOME/development/flutter/bin:$PATH"

pid_on() { ss -ltnp "sport = :$1" 2>/dev/null | grep -oP 'pid=\K\d+' | head -1; }
stop_port() { local p; p="$(pid_on "$1")"; [ -n "$p" ] && kill "$p" && echo "  berhenti: port $1"; return 0; }
wait_http() { for _ in $(seq 1 60); do curl -s -m 2 -o /dev/null "$1" && return 0; sleep 2; done; return 1; }

case "${1:-}" in
  up)
    echo "[1/3] Database"
    podman start kopi-mysql >/dev/null 2>&1
    for _ in $(seq 1 30); do podman exec kopi-mysql mysqladmin ping -uroot -proot --silent 2>/dev/null && break; sleep 2; done
    echo "[2/3] Backend  (log: /tmp/kopi-server.log)"
    stop_port 3000
    (cd "$ROOT/backend" && setsid nohup npx nest start > /tmp/kopi-server.log 2>&1 < /dev/null &)
    wait_http http://localhost:3000/outlets && echo "  OK  http://localhost:3000" || echo "  GAGAL, lihat /tmp/kopi-server.log"
    echo "[3/3] Panel admin  (log: /tmp/kopi-admin.log)"
    stop_port 3001
    (cd "$ROOT/admin" && { [ -d .next ] || npx next build >/dev/null 2>&1 < /dev/null; }; setsid nohup npx next start -p 3001 > /tmp/kopi-admin.log 2>&1 < /dev/null &)
    wait_http http://localhost:3001/login && echo "  OK  http://localhost:3001" || echo "  GAGAL, lihat /tmp/kopi-admin.log"
    echo; echo "Selanjutnya: ./dev.sh phone"
    ;;
  phone)
    "$ADB" start-server >/dev/null 2>&1
    state="$("$ADB" devices | awk 'NR>1 && $1!="" {print $2; exit}')"
    if [ "$state" != "device" ]; then
      echo "HP belum terdeteksi (status: ${state:-kosong})."
      echo "Cek: kabel mode 'Transfer file', USB tethering mati, Debugging USB nyala, lalu terima kotak izin di HP."
      exit 1
    fi
    "$ADB" reverse tcp:3000 tcp:3000 >/dev/null && echo "HP tersambung ke backend (adb reverse OK)"
    curl -s -m 3 -o /dev/null http://localhost:3000/outlets || echo "PERINGATAN: backend belum hidup, jalankan ./dev.sh up"
    cd "$ROOT/mobile" && exec flutter run --dart-define=API_URL=http://localhost:3000
    ;;
  watch)
    echo "Memantau HP; jalur adb reverse dipasang ulang otomatis. Tekan Ctrl+C untuk berhenti."
    last=""
    while true; do
      for ser in $("$ADB" devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}'); do
        if ! "$ADB" -s "$ser" reverse --list 2>/dev/null | grep -q "tcp:3000"; then
          "$ADB" -s "$ser" reverse tcp:3000 tcp:3000 >/dev/null 2>&1 && echo "$(date +%H:%M:%S) jalur dipasang ulang untuk $ser"
        fi
        last="$ser"
      done
      sleep 2
    done
    ;;
  photos)
    shift
    if [ $# -lt 1 ]; then echo "Pemakaian: ./dev.sh photos <folder> [--apply]"; exit 2; fi
    exec node "$ROOT/tool/upload-photos.mjs" "$@"
    ;;
  down)
    stop_port 3000; stop_port 3001; echo "selesai (database tetap hidup)"
    ;;
  status)
    echo "backend : $(curl -s -m 3 -o /dev/null -w '%{http_code}' http://localhost:3000/outlets)"
    echo "panel   : $(curl -s -m 3 -o /dev/null -w '%{http_code}' http://localhost:3001/login)"
    echo "HP      : $("$ADB" devices | awk 'NR>1 && $1!="" {print $2; exit}')"
    ;;
  *)
    sed -n '2,5p' "$0"; exit 1 ;;
esac
