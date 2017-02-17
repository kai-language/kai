#!/bin/bash

export SDKROOT=$(xcrun --show-sdk-path --sdk macosx)

FLAGS="-Xswiftc -DDebug -Xcc -I/usr/local/opt/llvm/include/ -Xlinker -L/usr/local/opt/llvm/lib/"

# No args, just build.
swift build $FLAGS

if [ $? -ne 0 ]; then

  exit 1
fi

cp .build/debug/kai $HOME/.dotfiles/bin/

if [ "$1" == "run" ]; then
  if [ -z "$2" ]; then
    .build/debug/kai samples/main.kai
    clang -o main main.o
  else 
    .build/debug/kai $2
  fi
fi

echo "done"
