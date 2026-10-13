#!/bin/sh
#
# smartctl wrapper for QNAP TS-431 (QTS 4.x has no smartctl).
# Runs Entware's smartmontools (built for armv7 / kernel 3.2) with Entware's
# glibc 2.27, both bundled next to this script, so Entware itself doesn't
# have to be installed. Installed as smartctl/bin/smartctl, the real binary
# is smartctl/bin/smartctl.real.
#
D=$(dirname "$0")/..
exec "$D/lib/ld-2.27.so" --library-path "$D/lib" "$D/bin/smartctl.real" "$@"
