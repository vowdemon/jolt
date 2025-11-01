#!/usr/bin/env bash
mkdir -p coverage
rm -f coverage/combined.info

for pkg in packages/*/; do
  if [ -f "$pkg/coverage/lcov.info" ]; then
    pkg_name=$(basename "$pkg")
    sed "s|^SF:lib/|SF:packages/$pkg_name/lib/|g" "$pkg/coverage/lcov.info" >> coverage/combined.info
  fi
done

# 删除 test 目录的 coverage
sed -i '/SF:.*\/test\//d' coverage/combined.info

# 生成 summary（行覆盖率）
awk '/DA:/{total++; if($0 ~ /,0$/) miss++;} END{print "Lines: " (total-miss)/total*100 "%"}' coverage/combined.info
