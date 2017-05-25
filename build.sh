#!/bin/bash

set -e

export SDKROOT=$(xcrun --show-sdk-path --sdk macosx)

FLAGS="-Xswiftc -DDEBUG -Xcc -I/usr/local/opt/llvm/include/ -Xlinker -L/usr/local/opt/llvm/lib/"

case "$1" in
run)
    swift build $FLAGS
    cp .build/debug/kai /usr/local/bin/

    if [ -z "$2" ]; then
        .build/debug/kai --emit-all samples/main.kai
    else
        .build/debug/kai --emit-all $2
    fi

    echo
    ./main
    echo
;;
xcode)
    swift package generate-xcodeproj $FLAGS
;;
*)
    swift build $FLAGS
    cp .build/debug/kai /usr/local/bin/
esac

echo "done"
