#!/usr/bin/env bash
# publish_content.sh 테스트. PATH 앞에 가짜 curl을 두고 Storage 응답을 흉내 낸다. 네트워크를 쓰지 않는다.
# 실행: bash .github/scripts/publish_content_test.sh
set -u

here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir "$work/bin"
cat > "$work/bin/curl" <<'FAKE'
#!/usr/bin/env bash
# 가짜 curl: 요청을 $FAKE_LOG에 한 줄씩 남기고, -o 파일에 본문을, 표준 출력에 상태 코드(-w)를 쓴다.
# FAKE_EXIT가 있으면 연결 실패처럼 그 코드로 끝난다.
if [ -n "${FAKE_EXIT:-}" ]; then echo "curl: ($FAKE_EXIT) Could not resolve host" >&2; exit "$FAKE_EXIT"; fi
method=GET out=/dev/null url="" data="" headers=""
while [ $# -gt 0 ]; do
  case "$1" in
    -X) method=$2; shift ;;
    -o) out=$2; shift ;;
    -H) headers="$headers [$2]"; shift ;;
    --data-binary) data=$2; method=${method/GET/POST}; shift ;;
    -w|--max-time) shift ;;
    -*) ;;
    *) url=$1 ;;
  esac
  shift
done
case "$method $url" in
  "GET "*/manifest.json) code=$GET_CODE body=$GET_BODY ;;
  "POST "*/manifest.json) code=200 body='{"Key":"content/manifest"}' ;;
  "POST "*) code=$BODY_CODE body=$BODY_RESP ;;
  *) code=500 body=unexpected ;;
esac
echo "$method ${url#*/storage/v1/}$headers $data" >> "$FAKE_LOG"
printf '%s' "$body" > "$out"
printf '%s' "$code"
FAKE
chmod +x "$work/bin/curl"

content() { printf '{"schema": 1, "version": %s, "principles": []}' "$1" > "$work/content.json"; }
content 3

fails=0
# run <이름> <GET 코드> <GET 본문> <본문 업로드 코드> <본문 업로드 응답>: 결과는 $status, $log
run() {
  name=$1
  : > "$work/log"
  GET_CODE=$2 GET_BODY=$3 BODY_CODE=$4 BODY_RESP=$5 FAKE_LOG="$work/log" \
    SUPABASE_URL=https://example.supabase.co SUPABASE_SERVICE_ROLE_KEY=test-key \
    PATH="$work/bin:$PATH" bash "$here/publish_content.sh" "$work/content.json" > "$work/out" 2>&1
  status=$?
  log=$(cat "$work/log")
}
check() { # check <설명> <조건 결과>
  if [ "$2" -eq 0 ]; then echo "ok   $name: $1"; else echo "FAIL $name: $1"; fails=$((fails + 1)); sed 's/^/     /' "$work/out" "$work/log"; fi
}
uploads() { grep -c '^POST ' "$work/log"; }
nth_post() { grep '^POST ' "$work/log" | sed -n "${1}p"; }

run "manifest version 같음" 200 '{"version": 3}' 200 '{}'
[ "$status" -eq 0 ]; check "종료 코드 0" $?
[ "$(uploads)" -eq 0 ]; check "업로드 요청 0번" $?

run "manifest 없음" 400 '{"statusCode":"404","error":"not_found","message":"Object not found"}' 200 '{}'
[ "$status" -eq 0 ]; check "종료 코드 0" $?
[ "$(uploads)" -eq 2 ]; check "업로드 요청 2번" $?
nth_post 1 | grep -q '^POST object/content/s1/3.json \[.*x-upsert: false\].*\[cache-control: max-age=31536000\]'; check "먼저 본문 s1/3.json (x-upsert false, max-age=31536000)" $?
nth_post 2 | grep -q '^POST object/content/s1/manifest.json \[.*x-upsert: true\].*\[cache-control: max-age=60\].* {"version": 3}$'; check "다음 manifest (x-upsert true, max-age=60, {\"version\": 3})" $?

run "manifest가 더 작음" 200 '{"version": 2}' 200 '{}'
[ "$status" -eq 0 ]; check "종료 코드 0" $?
[ "$(uploads)" -eq 2 ]; check "업로드 요청 2번" $?

run "manifest가 더 큼" 200 '{"version": 4}' 200 '{}'
[ "$status" -ne 0 ]; check "실패" $?
[ "$(uploads)" -eq 0 ]; check "업로드 요청 0번" $?

run "본문이 이미 있음" 200 '{"version": 2}' 400 '{"statusCode":"409","error":"Duplicate","message":"The resource already exists"}'
[ "$status" -eq 0 ]; check "종료 코드 0" $?
nth_post 2 | grep -q '^POST object/content/s1/manifest.json'; check "manifest를 올림" $?

run "본문 업로드 실패" 200 '{"version": 2}' 500 '{"error":"internal"}'
[ "$status" -ne 0 ]; check "실패" $?
[ "$(uploads)" -eq 1 ]; check "manifest를 올리지 않음" $?

run "manifest 받기 실패" 500 'error' 200 '{}'
[ "$status" -ne 0 ]; check "실패" $?
[ "$(uploads)" -eq 0 ]; check "업로드 요청 0번" $?

run "키를 출력하지 않음" 400 '{"statusCode":"404","error":"not_found"}' 200 '{}'
! grep -q test-key "$work/out"; check "출력에 키가 없음" $?
grep -q '^GET object/content/s1/manifest.json .*\[apikey: test-key\] \[Authorization: Bearer test-key\]' "$work/log"; check "요청에 apikey와 Authorization 헤더가 있음" $?

run "버킷 없음" 400 '{"statusCode":"404","error":"Bucket not found"}' 200 '{}'
[ "$status" -ne 0 ]; check "실패" $?
[ "$(uploads)" -eq 0 ]; check "업로드 요청 0번" $?

run "본문이 너무 큼" 200 '{"version": 2}' 400 '{"statusCode":"413","error":"Payload too large"}'
[ "$status" -ne 0 ]; check "실패" $?
[ "$(uploads)" -eq 1 ]; check "manifest를 올리지 않음" $?

export FAKE_EXIT=6
run "curl 연결 실패" 200 '{"version": 2}' 200 '{}'
unset FAKE_EXIT
[ "$status" -ne 0 ]; check "실패" $?

for v in 3.5 3.0; do
  content "$v"
  run "version $v" 400 '{"statusCode":"404","error":"not_found"}' 200 '{}'
  [ "$status" -ne 0 ]; check "실패" $?
  [ "$(uploads)" -eq 0 ]; check "업로드 요청 0번" $?
done
printf '{"schema": 1}' > "$work/content.json"
run "version 없음" 400 '{"statusCode":"404","error":"not_found"}' 200 '{}'
[ "$status" -ne 0 ]; check "실패" $?
grep -q "schema/version이 없다: $work/content.json" "$work/out"; check "파일 경로와 함께 알림" $?
[ "$(uploads)" -eq 0 ]; check "업로드 요청 0번" $?
content 3

run "manifest version 2.5" 200 '{"version": 2.5}' 200 '{}'
[ "$status" -ne 0 ]; check "실패" $?
[ "$(uploads)" -eq 0 ]; check "업로드 요청 0번" $?

[ "$fails" -eq 0 ] && echo "모두 통과" || { echo "실패 $fails개"; exit 1; }
