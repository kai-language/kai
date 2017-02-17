#!/bin/bash

set -e

export SDKROOT=$(xcrun --show-sdk-path --sdk macosx)

FLAGS="-Xswiftc -DDebug -Xcc -I/usr/local/opt/llvm/include/ -Xlinker -L/usr/local/opt/llvm/lib/"

# No args, just build.
swift build $FLAGS

if [ $? -ne 0 ]; then

  exit 1
fi

cp .build/debug/kai $HOME/.dotfiles/bin/

case "$1" in
run)

    if [ -z "$2" ]; then
        .build/debug/kai samples/main.kai
        clang -o main main.o
    else
        .build/debug/kai $2
    fi

    echo
    ./main
    echo
;;
xcode)
    swift package generate-xcodeproj $FLAGS
;;
esac

echo "done"
