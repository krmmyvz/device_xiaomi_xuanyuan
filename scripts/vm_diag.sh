#!/usr/bin/env bash
# Kesin tani: project.list <-> base manifest isim karsilastirmasi ve
# kalan sync hatalarinin tam listesi.
cd /mnt/src

echo "=== project.list ilk 8 satir ==="
head -8 .repo/project.list
echo "satir: $(wc -l < .repo/project.list)"

echo
echo "=== bu isimler base default.xml'de var mi ==="
while read -r n; do
  c=$(grep -c "name=\"$n\"" .repo/manifests/default.xml 2>/dev/null || echo 0)
  printf "  %-46s default.xml'de: %s\n" "$n" "$c"
done < <(head -3 .repo/project.list)

echo
echo "=== kalan sync hatalari (tam) ==="
grep -oE "on [a-zA-Z0-9_/.+-]+ failed|unsupported checkout state|not a git repository: '[^']+'|object file [^ ]+ is empty" /mnt/out/sync-round.log | sort | uniq -c | sort -rn | head -20

echo
echo "=== hangi yollarda 'unsupported checkout state' ==="
grep -oE "/mnt/src/[^ ]+\.git: unsupported checkout state" /mnt/out/sync-round.log | sort -u | head -15

echo
echo "=== default.xml include'leri ==="
grep -n "<include" .repo/manifests/default.xml | head -6
echo "snippets icerigi:"
ls .repo/manifests/snippets/
