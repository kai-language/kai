#!/bin/bash

set -e

case "$1" in
xcode)
    swift package generate-xcodeproj 
;;

sourcery)
    ./tools/genAccessors.sh
;;

*)
    MACOSX_DEPLOYMENT_TARGET=10.12
    swift build -Xswiftc -DDEBUG -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx10.12"
    cp .build/debug/kai /usr/local/bin/
esac

echo "done"

