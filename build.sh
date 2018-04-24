#!/bin/bash

set -e

debug_build() {
    case "$platform" in
    macOS) swift build -Xswiftc -DDEBUG -Xswiftc -DDEVELOPER -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx$MACOSX_DEPLOYMENT_TARGET" ;;
    linux) swift build -Xswiftc -DDEBUG -Xswiftc -DDEVELOPER -Xswiftc "-target" -Xswiftc "x86_64-pc-linux-gnu" ;;
    esac
}

unsupportedCommand() {
    echo "Unsupported command $1"
    exit 1
}

case "$OSTYPE" in
  darwin*)  platform="macOS" ;;
  linux*)   platform="linux" ;;
  *)
      echo "unknown OS build script will need updating for support"
      exit 1
  ;;
esac

MACOSX_DEPLOYMENT_TARGET=10.13

case "$1" in
xcode)
    if [ "$platform" != "macOS" ]; then
        unsupportedCommand "xcode"
    fi
    swift package generate-xcodeproj
;;
release)
    case "$platform" in
        macOS) swift build -Xswiftc -DDEBUG -Xswiftc -static-stdlib -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx$MACOSX_DEPLOYMENT_TARGET" -c release ;;
        linux) swift build -Xswiftc -DDEBUG -Xswiftc -static-stdlib -Xswiftc "-target" -Xswiftc "x86_64-pc-linux-gnu" -c release ;;
        *)
            unsupportedCommand "release"
    esac
    cp .build/release/kai /usr/local/bin/
;;
*)
    debug_build
    cp .build/debug/kai /usr/local/bin/
esac

echo "done"
