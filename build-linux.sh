#!/bin/bash

set -e

case "$1" in
sourcery)
    ./tools/genAccessors.sh
;;
release)
    echo "building binary"

    swift build -Xswiftc -DDEBUG -Xswiftc "-target" -Xswiftc "x86_64-pc-linux-gnu" -c release
    cp .build/release/kai /usr/local/bin/
;;
*)
    swift build -Xswiftc -DDEBUG -Xswiftc -DDEVELOPER -Xswiftc "-target" -Xswiftc "x86_64-pc-linux-gnu"
    cp .build/debug/kai /usr/local/bin/
esac

echo "done"

