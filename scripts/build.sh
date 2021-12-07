#!/bin/bash
#
# build.sh

PKGS=$(./void-packages/xbps-src sort-dependencies $(cat /tmp/templates))

for pkg in ${PKGS}; do
	./void-packages/xbps-src -j$(nproc) pkg "$pkg" || exit 1
done

exit 0
