# 서버 배치 (Oracle Ubuntu 24.04)

기존 newsmonitor 인스턴스를 재사용한다. 포트 **8090**.

```bash
# 1. 코드 올리기
sudo mkdir -p /opt/foodlog && sudo chown ubuntu:ubuntu /opt/foodlog
scp server/server.py server/requirements.txt ubuntu@<서버>:/opt/foodlog/

# 2. 가상환경
cd /opt/foodlog
python3 -m venv venv
venv/bin/pip install -r requirements.txt

# 3. 환경 파일
sudo cp foodlog.env.example /etc/foodlog.env
sudo chmod 600 /etc/foodlog.env
sudo nano /etc/foodlog.env   # 키·토큰 채우기

# 4. systemd
sudo cp foodlog.service /etc/systemd/system/foodlog.service
sudo systemctl daemon-reload
sudo systemctl enable --now foodlog

# 5. Tailscale Funnel — 기존 newsmonitor 설정에 경로 추가
sudo tailscale funnel --bg --set-path /foodlog http://127.0.0.1:8090
# 앱의 서버 주소: https://<장비명>.<tailnet>.ts.net/foodlog
```

## curl 검증

```bash
BASE=https://<장비명>.<tailnet>.ts.net/foodlog
TOKEN=<APP_TOKENS 중 하나>

curl -s $BASE/v1/health

# 사진 분석
b64=$(base64 -w0 test.jpg)
curl -s -X POST $BASE/v1/analyze \
  -H "X-App-Token: $TOKEN" -H "Content-Type: application/json" \
  -d "{\"images\":[{\"data\":\"$b64\",\"taken_at\":\"2026-09-06T12:31:00+09:00\"}],\"mode\":\"meal\"}"

# 바코드
curl -s -H "X-App-Token: $TOKEN" $BASE/v1/barcode/8801043015337
```

## 확인 필요

- `MFDS_API_KEY`는 공공데이터포털 [식품영양성분DB정보](https://www.data.go.kr/data/15127578/openapi.do)
  인증키(**Decoding 키**). 배치 후 아래로 검증:

  ```bash
  curl -s -H "X-App-Token: $TOKEN" "$BASE/v1/food/search?q=김치찌개"
  ```

  결과가 비어 있으면 공식 문서의 응답 필드명 기준으로 `server.py` `food_search()`의
  필드 매핑(AMT_NUM1 등)을 조정한다.
