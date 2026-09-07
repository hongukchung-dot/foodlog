# 서버 배치 (Oracle Ubuntu 24.04)

기존 newsmonitor 인스턴스를 재사용한다. 포트 **8090**.

## 자동 배치 (권장)

```bash
ssh ubuntu@<서버주소>
git clone https://github.com/hongukchung-dot/foodlog.git   # 비공개면 토큰 필요, 아래 참고
cd foodlog
./server/deploy.sh
```

스크립트가 하는 일: 패키지 설치 → `/opt/foodlog` 코드 배치 → venv/의존성 →
`/etc/foodlog.env` 생성(앱 토큰 자동 생성, admin/friend 별도) → systemd 등록·기동 →
로컬 헬스체크 → Tailscale Funnel `/foodlog` 경로 설정.

처음 실행 후 `sudo nano /etc/foodlog.env` 로 `ANTHROPIC_API_KEY`(필수),
`MFDS_API_KEY`(선택)를 채우고 `sudo systemctl restart foodlog`.

- 비공개 저장소 클론: GitHub → Settings → Developer settings → Fine-grained token
  (이 저장소 Contents: Read)을 만들어
  `git clone https://<토큰>@github.com/hongukchung-dot/foodlog.git`
- 코드 갱신 배포: `cd ~/foodlog && git pull && ./server/deploy.sh`
- 로그 확인: `sudo journalctl -u foodlog -f`

## 수동 배치 (참고)

`deploy.sh` 내용과 동일 — 코드 복사 → venv → env 파일 → systemd → Funnel 순서.

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
  # 한글 쿼리는 반드시 --data-urlencode 로 (curl은 URL 인코딩을 자동으로 하지 않음)
  curl -s -G -H "X-App-Token: $TOKEN" --data-urlencode "q=김치찌개" "$BASE/v1/food/search"
  ```

  결과가 비어 있으면 공식 문서의 응답 필드명 기준으로 `server.py` `food_search()`의
  필드 매핑(AMT_NUM1 등)을 조정한다.
