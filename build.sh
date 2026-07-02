#!/bin/sh
# Build godaddy-ddns-<version>.spk from the source tree.
# Usage: ./build.sh [version]   (default 1.0.0)
set -e

VERSION="${1:-1.1.0}"
SRC="$(cd "$(dirname "$0")" && pwd)"
OUT="$SRC/dist"
STAGE="$OUT/stage"

# Prevent macOS AppleDouble (._*) files from poisoning the tarballs.
export COPYFILE_DISABLE=1

rm -rf "$STAGE"
mkdir -p "$STAGE/scripts" "$STAGE/WIZARD_UIFILES" "$OUT"

# package.tgz: the payload extracted to /var/packages/godaddy-ddns/target
chmod 755 "$SRC"/package/bin/*.sh
tar -C "$SRC/package" --exclude '.DS_Store' -czf "$STAGE/package.tgz" bin etc

# INFO with version + payload checksum filled in
CHECKSUM=$(md5 -q "$STAGE/package.tgz" 2>/dev/null || md5sum "$STAGE/package.tgz" | cut -d' ' -f1)
sed -e "s/@VERSION@/$VERSION/" -e "s/@CHECKSUM@/$CHECKSUM/" "$SRC/INFO.in" > "$STAGE/INFO"

cp "$SRC"/scripts/* "$STAGE/scripts/"
chmod 755 "$STAGE"/scripts/*
cp "$SRC"/WIZARD_UIFILES/* "$STAGE/WIZARD_UIFILES/"

for icon in PACKAGE_ICON.PNG PACKAGE_ICON_256.PNG; do
    [ -f "$SRC/$icon" ] && cp "$SRC/$icon" "$STAGE/$icon"
done

SPK="$OUT/godaddy-ddns-$VERSION.spk"
rm -f "$SPK"
(cd "$STAGE" && tar --exclude '.DS_Store' -cf "$SPK" INFO package.tgz scripts WIZARD_UIFILES PACKAGE_ICON.PNG PACKAGE_ICON_256.PNG 2>/dev/null \
    || tar --exclude '.DS_Store' -cf "$SPK" INFO package.tgz scripts WIZARD_UIFILES)

rm -rf "$STAGE"
echo "Built $SPK"
