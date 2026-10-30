#!/usr/bin/env bash
# 콘텐츠 검사 (ADR 0003 §6, ADR 0009 §3): JSON Schema(ajv) 다음 validate_content.
# 사용: bash .github/scripts/check_content.sh app/assets/content.json [이전 파일]
# 이전 파일이 없거나 비어 있으면 --previous 없이 파일 하나만 검사한다.
# 출처는 늘 리포의 근거 색인 pipeline/sources/sources.json과 대조한다(ADR 0009 §6).
set -euo pipefail

# app/에서 dart를 돌리므로 리포 루트로 옮기기 전에 경로를 절대 경로로 바꾼다.
abs() { (cd "$(dirname "$1")" && echo "$PWD/$(basename "$1")"); }
file=$(abs "$1")
prev=${2:+$(abs "$2")}
cd "$(dirname "$0")/../.."
sources=$PWD/pipeline/sources/sources.json

npx --yes ajv-cli@5.0.0 validate --spec=draft7 -s app/assets/content.schema.json -d "$file"
cd app && dart run tool/validate_content.dart "$file" "--sources=$sources" ${prev:+"--previous=$prev"}
