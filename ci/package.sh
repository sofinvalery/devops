#!/usr/bin/env bash
set -euo pipefail

if ! command -v dpkg-deb >/dev/null 2>&1; then
    echo "Error: dpkg-deb not found. Install dpkg-dev."
    exit 1
fi

if ! command -v dpkg >/dev/null 2>&1; then
    echo "Error: dpkg not found. This script requires Debian/Ubuntu tools."
    exit 1
fi

make clean
make

PKG_NAME="reverse"
PKG_VERSION="${PKG_VERSION:-1.0.0}"
PKG_ARCH="$(dpkg --print-architecture)"
PKG_DIR="build/${PKG_NAME}_${PKG_VERSION}_${PKG_ARCH}"
PKG_FILE="dist/${PKG_NAME}_${PKG_VERSION}_${PKG_ARCH}.deb"

rm -rf "${PKG_DIR}" dist
mkdir -p "${PKG_DIR}/DEBIAN" "${PKG_DIR}/usr/bin" dist
install -m 0755 reverse "${PKG_DIR}/usr/bin/reverse"

cat > "${PKG_DIR}/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${PKG_VERSION}
Section: utils
Priority: optional
Architecture: ${PKG_ARCH}
Depends: libc6
Maintainer: Valeriy Sofin <valeriysofin@local>
Description: 7x7 matrix task executable
 Random 7x7 matrix analyzer that zeroes the matrix when counts match.
EOF

dpkg-deb --build --root-owner-group "${PKG_DIR}" "${PKG_FILE}"

echo "Package created: ${PKG_FILE}"
