#!/usr/bin/env bash
# 푸드로그 서버 배치 스크립트 — Oracle Ubuntu 인스턴스에서 실행한다.
# 사용법: 저장소를 클론한 뒤  ./server/deploy.sh
# 여러 번 실행해도 안전(멱등). 코드 갱신 시 git pull 후 다시 실행하면 된다.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR=/opt/foodlog
ENV_FILE=/etc/foodlog.env
PORT=8090

echo "== 1. 필수 패키지 =="
sudo apt-get update -qq
sudo apt-get install -y -qq python3-venv curl >/dev/null

echo "== 2. 코드 배치 → $APP_DIR =="
sudo mkdir -p "$APP_DIR"
sudo chown "$USER":"$USER" "$APP_DIR"
cp "$SRC_DIR/server.py" "$SRC_DIR/requirements.txt" "$APP_DIR/"

echo "== 3. 가상환경 및 의존성 =="
if [ ! -x "$APP_DIR/venv/bin/pip" ]; then
    python3 -m venv "$APP_DIR/venv"
fi
"$APP_DIR/venv/bin/pip" install -q --upgrade pip
"$APP_DIR/venv/bin/pip" install -q -r "$APP_DIR/requirements.txt"

echo "== 4. 환경 파일 ($ENV_FILE) =="
if [ ! -f "$ENV_FILE" ]; then
    sudo cp "$SRC_DIR/foodlog.env.example" "$ENV_FILE"
    ADMIN_TOKEN=$(openssl rand -hex 24)
    FRIEND_TOKEN=$(openssl rand -hex 24)
    sudo sed -i "s/^APP_TOKENS=.*/APP_TOKENS=${ADMIN_TOKEN},${FRIEND_TOKEN}/" "$ENV_FILE"
    sudo chmod 600 "$ENV_FILE"
    echo ""
    echo "  앱 토큰을 자동 생성했습니다. 앱 설정 화면에 넣으세요:"
    echo "    admin  토큰: $ADMIN_TOKEN"
    echo "    friend 토큰: $FRIEND_TOKEN"
    echo ""
    echo "  ⚠️  이제 키를 채워야 합니다:  sudo nano $ENV_FILE"
    echo "      - ANTHROPIC_API_KEY (console.anthropic.com)"
    echo "      - MFDS_API_KEY (data.go.kr 15127578, Decoding 키 — 없어도 동작)"
    NEED_KEYS=1
else
    echo "  기존 $ENV_FILE 유지"
    NEED_KEYS=0
fi

echo "== 5. systemd 서비스 =="
sudo cp "$SRC_DIR/foodlog.service" /etc/systemd/system/foodlog.service
# 이 스크립트를 실행한 계정으로 서비스 구동 (기본 유닛은 ubuntu 가정)
sudo sed -i "s/^User=.*/User=$USER/; s/^Group=.*/Group=$USER/" /etc/systemd/system/foodlog.service
sudo systemctl daemon-reload
sudo systemctl enable foodlog >/dev/null
sudo systemctl restart foodlog

echo "== 6. 로컬 헬스체크 (최대 30초 대기) =="
ok=0
for i in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:$PORT/v1/health" 2>/dev/null; then
        echo "  ← health OK (${i}s)"
        ok=1
        break
    fi
    # 기동 실패로 이미 죽었으면 바로 로그 출력
    if ! systemctl is-active --quiet foodlog; then
        break
    fi
    sleep 1
done
if [ "$ok" != "1" ]; then
    echo "  !! 서비스가 응답하지 않습니다. 최근 로그:"
    sudo journalctl -u foodlog -n 30 --no-pager | sed 's/^/    /'
    exit 1
fi

echo "== 7. Tailscale Funnel (/foodlog 경로) =="
if command -v tailscale >/dev/null; then
    sudo tailscale funnel --bg --set-path /foodlog "http://127.0.0.1:$PORT" \
        && echo "  Funnel 설정 완료" \
        || echo "  !! Funnel 설정 실패 — 'sudo tailscale funnel status' 로 확인"
    echo "  외부 주소 확인:"
    tailscale funnel status 2>/dev/null | sed 's/^/    /' || true
else
    echo "  tailscale 미설치 — https://tailscale.com/download 후 다시 실행"
fi

echo ""
echo "== 완료 =="
if [ "$NEED_KEYS" = "1" ]; then
    echo "1) sudo nano $ENV_FILE  로 API 키를 채운 뒤  sudo systemctl restart foodlog"
fi
echo "2) 앱 설정 화면: 서버 주소 = https://<장비명>.<tailnet>.ts.net/foodlog, 위 앱 토큰 입력"
echo "3) 외부 검증:"
echo "   curl -s https://<장비명>.<tailnet>.ts.net/foodlog/v1/health"
echo "   curl -s -H 'X-App-Token: <토큰>' 'https://<장비명>.<tailnet>.ts.net/foodlog/v1/food/search?q=김치찌개'"
