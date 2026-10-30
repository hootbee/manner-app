#!/usr/bin/env bash
# check_content.sh 테스트. 지금 app/assets/content.json을 jq로 조금씩 바꿔 검사한다.
# ajv-cli는 npx가 처음 한 번 내려받고, dart는 app/의 패키지를 쓴다.
# 실행: bash .github/scripts/check_content_test.sh
set -u

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
real=app/assets/content.json

fails=0
# run <이름> <돌릴 폴더> <check_content.sh 인자...>: 결과는 $status
run() {
  name=$1 dir=$2
  shift 2
  (cd "$dir" && bash "$here/check_content.sh" "$@") > "$work/out" 2>&1
  status=$?
}
check() { # check <설명> <조건 결과>
  if [ "$2" -eq 0 ]; then echo "ok   $name: $1"; else echo "FAIL $name: $1"; fails=$((fails + 1)); sed 's/^/     /' "$work/out"; fi
}

run "지금 파일, 이전 파일도 같음" "$root" "$real" "$real"
[ "$status" -eq 0 ]; check "종료 코드 0" $?

run "이전 파일 없음" "$root" "$real"
[ "$status" -eq 0 ]; check "종료 코드 0" $?

run "app/에서 부름" "$root/app" assets/content.json assets/content.json
[ "$status" -eq 0 ]; check "종료 코드 0" $?

# A-alley의 child 축을 빼면 펼친 문제 A-alley~child만 사라진다. version을 올려 다른 오류는 나지 않게 한다.
jq '.version += 1 | (.scenarios[] | select(.id == "A-alley") | .vary[0]) |= map(select(.key != "child"))' \
  "$root/$real" > "$work/no-child.json"
run "펼친 문제를 지움" "$root" "$work/no-child.json" "$real"
[ "$status" -eq 1 ]; check "종료 코드 1" $?
grep -q 'A-alley~child' "$work/out"; check "출력에 A-alley~child가 있음" $?

# 모르는 최상위 속성은 ajv만 막는다(validate_content는 통과).
jq '.extra = 1' "$root/$real" > "$work/extra.json"
run "스키마 위반 (모르는 속성)" "$root" "$work/extra.json"
[ "$status" -ne 0 ]; check "실패" $?
grep -q 'must NOT have additional properties' "$work/out"; check "ajv가 알림" $?

# locator는 선택이다(ADR 0009 §6). 모든 출처에서 지워도 ajv와 validate_content가 통과한다.
jq '(.scenarios[] | select(.evidence) | .evidence.sources[]) |= del(.locator)' "$root/$real" > "$work/no-locator.json"
run "출처에 locator 없음" "$root" "$work/no-locator.json"
[ "$status" -eq 0 ]; check "종료 코드 0" $?

[ "$fails" -eq 0 ] && echo "모두 통과" || { echo "실패 $fails개"; exit 1; }
