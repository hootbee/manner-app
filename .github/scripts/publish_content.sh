#!/usr/bin/env bash
# 콘텐츠를 Storage content 버킷에 올린다 (ADR 0003 §5).
# 사용: SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... bash .github/scripts/publish_content.sh app/assets/content.json
# 본문 s<schema>/<version>.json(x-upsert false)을 먼저, manifest s<schema>/manifest.json(x-upsert true)을 나중에 올린다.
# 다시 실행해도 안전하다: manifest version이 같으면 아무것도 안 하고, 크면 실패하고, 본문이 이미 있으면 manifest만 올린다.
set -euo pipefail

file=$1
: "${SUPABASE_URL:?}" "${SUPABASE_SERVICE_ROLE_KEY:?}"
schema=$(jq -er '.schema' "$file") && version=$(jq -er '.version' "$file") ||
  { echo "schema/version이 없다: $file" >&2; exit 1; }
# 정수가 아니면 [ -eq ]가 거짓으로 끝나 그대로 올라가므로 먼저 막는다. jq 1.7은 3.0을 3.0으로 출력한다.
if ! [[ $schema =~ ^[1-9][0-9]*$ && $version =~ ^[1-9][0-9]*$ ]]; then
  echo "schema와 version은 양의 정수여야 한다: schema=$schema version=$version" >&2
  exit 1
fi
base="$SUPABASE_URL/storage/v1/object/content/s$schema"
resp=$(mktemp)
trap 'rm -f "$resp"' EXIT

# storage <curl 인자...>: 응답 본문은 $resp에, 상태 코드는 표준 출력에.
storage() {
  curl -sS --max-time 60 -o "$resp" -w '%{http_code}' \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" "$@"
}
# error_is <이름>: Storage 오류 응답의 error가 <이름>인지. 없는 파일과 이미 있는 파일은 둘 다 HTTP 400으로 온다.
error_is() { [ "$(jq -r '.error? // empty' "$resp" 2>/dev/null)" = "$1" ]; }

code=$(storage "$base/manifest.json")
if [ "$code" = 200 ]; then
  current=$(jq -r '.version? // empty' "$resp" 2>/dev/null || true)
  if ! [[ $current =~ ^(0|[1-9][0-9]*)$ ]]; then
    echo "올라간 manifest의 version이 정수가 아니다: $(cat "$resp")" >&2
    exit 1
  fi
elif [ "$code" = 400 ] && error_is not_found; then
  current=0
else
  echo "manifest를 받지 못했다: HTTP $code $(cat "$resp")" >&2
  exit 1
fi
echo "올라간 version: $current, 올릴 version: $version (schema $schema)"

if [ "$current" -eq "$version" ]; then
  echo "이미 올라가 있다. 아무것도 하지 않는다"
  exit 0
fi
if [ "$current" -gt "$version" ]; then
  echo "올라간 version이 더 크다. 올리지 않는다" >&2
  exit 1
fi

code=$(storage -X POST -H 'x-upsert: false' -H 'cache-control: max-age=31536000' \
  -H 'content-type: application/json' --data-binary "@$file" "$base/$version.json")
if [ "$code" = 400 ] && error_is Duplicate; then
  echo "s$schema/$version.json은 이미 있다. manifest만 올린다"
elif [ "$code" != 200 ]; then
  echo "본문을 올리지 못했다: HTTP $code $(cat "$resp")" >&2
  exit 1
fi

code=$(storage -X POST -H 'x-upsert: true' -H 'cache-control: max-age=60' \
  -H 'content-type: application/json' --data-binary "{\"version\": $version}" "$base/manifest.json")
if [ "$code" != 200 ]; then
  echo "manifest를 올리지 못했다: HTTP $code $(cat "$resp")" >&2
  exit 1
fi
echo "올렸다: s$schema/$version.json, s$schema/manifest.json"
