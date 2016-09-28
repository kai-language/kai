#!/bin/bash

# Must have swiftenv installed here. Default for homebrew
CC=`/usr/local/bin/swiftenv which swift`

#echo "Using $CC"
export SDKROOT=$(xcrun --show-sdk-path --sdk macosx)

FLAGS="-Xswiftc -DDebug -Xcc -I/usr/local/opt/llvm/include/ -Xlinker -L/usr/local/opt/llvm/lib/"

# No args, just build.
if [ -z "$1" ]; then

  $CC build $FLAGS

  if [ $? -ne 0 ]; then

    exit 1
  fi
else

  $CC $1 $FLAGS
fi

cp .build/debug/kai $HOME/.dotfiles/bin/

