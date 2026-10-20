#!/usr/bin/env bash
# 스토어 스크린샷 만들기: 글꼴을 받고 실제 앱 화면을 이미지로 렌더링한다.
# 결과: store_screenshots/out/{android,iphone}/*.png
set -euo pipefail
cd "$(dirname "$0")/.."

FONT_DIR=store_screenshots/fonts
BASE=https://github.com/google/fonts/raw/main/ofl
mkdir -p "$FONT_DIR"
for path in \
  ibmplexsanskr/IBMPlexSansKR-Regular.ttf \
  ibmplexsanskr/IBMPlexSansKR-Medium.ttf \
  ibmplexsanskr/IBMPlexSansKR-Bold.ttf \
  blackhansans/BlackHanSans-Regular.ttf \
  spacemono/SpaceMono-Bold.ttf; do
  file="$FONT_DIR/$(basename "$path")"
  [ -s "$file" ] || curl -fsSL "$BASE/$path" -o "$file"
done

rm -rf store_screenshots/out
flutter test store_screenshots "$@"
