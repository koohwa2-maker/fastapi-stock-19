#!/usr/bin/env bash
# EC2(Ubuntu) 서버에서 실행되는 배포 스크립트. 여러 번 실행해도 안전하다.
set -euo pipefail

APP_DIR="$HOME/app"
SERVICE=fastapi-stock

# 1. 필요한 패키지 (최초 1회만 설치)
if ! command -v nginx >/dev/null; then
  sudo apt-get update -y
  sudo apt-get install -y nginx curl
fi
if [ ! -x "$HOME/.local/bin/uv" ]; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
UV="$HOME/.local/bin/uv"

# 2. 의존성 설치
cd "$APP_DIR"
"$UV" sync --frozen --no-dev

# 3. systemd 서비스 (uvicorn, 127.0.0.1:8000)
sudo tee /etc/systemd/system/$SERVICE.service >/dev/null <<EOF
[Unit]
Description=FastAPI stock app
After=network.target

[Service]
User=$USER
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/.venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 4. nginx: 80 포트 -> 8000 포트
sudo tee /etc/nginx/sites-available/$SERVICE >/dev/null <<'EOF'
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF
sudo ln -sf /etc/nginx/sites-available/$SERVICE /etc/nginx/sites-enabled/$SERVICE
sudo rm -f /etc/nginx/sites-enabled/default

# 5. 재시작
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE >/dev/null
sudo systemctl restart $SERVICE
sudo nginx -t
sudo systemctl reload nginx

# 6. 헬스 체크
for i in $(seq 1 15); do
  if curl -fs http://127.0.0.1:8000/ >/dev/null; then
    echo "배포 성공"
    exit 0
  fi
  sleep 2
done
echo "앱이 응답하지 않습니다" >&2
sudo journalctl -u $SERVICE -n 50 --no-pager >&2
exit 1
