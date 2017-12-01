#!/bin/bash

set -e

MACOSX_DEPLOYMENT_TARGET=10.13

case "$1" in
xcode)
    swift package generate-xcodeproj
;;

sourcery)
    ./tools/genAccessors.sh
;;
release)
    swift build -Xswiftc -DDEBUG -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx$MACOSX_DEPLOYMENT_TARGET" -c release
    cp .build/release/kai /usr/local/bin/
;;
distribute)
    TAG=$(git describe --abbrev=0 --tags);
    git checkout $TAG;
    cat ./Sources/Core/Options.swift | \
        awk -v tag="$TAG" '/public static let version = "0.0.0"/ { printf "    public static let version = \"%s\"\n", tag; next } 1' > .tmp && \
    mv .tmp ./Sources/Core/Options.swift;

    echo "building binary"

    swift build -c release -Xswiftc -static-stdlib -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx$MACOSX_DEPLOYMENT_TARGET"
    install_name_tool -change /usr/local/opt/llvm/lib/libc++.1.dylib /usr/lib/libc++.1.dylib .build/release/kai
    PACKAGE_NAME="kai-$TAG"
    mkdir -p ./$PACKAGE_NAME
    cp .build/release/kai ./$PACKAGE_NAME/kai
    tar -cvzf macOS-sierra.tar.gz ./$PACKAGE_NAME

    echo "updating brew formula"

    HASH=$(shasum -a 256 macOS-sierra.tar.gz | cut -d " " -f 1)
    curl -sO https://raw.githubusercontent.com/kai-language/homebrew-tap/kai/kai.rb
    cat kai.rb | awk -v tag="$TAG" -v hash="$HASH" '/version "*"/ { printf "  version \"%s\"\n", tag; next }/sha256/ { printf "  sha256 \"%s\"\n", hash; next } 1' > .tmp && \
        mv .tmp kai.rb

    echo "restoring working directory"

    rm -rf $PACKAGE_NAME
    git reset --hard HEAD
;;
*)
    swift build -Xswiftc -DDEBUG -Xswiftc -DDEVELOPER -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx$MACOSX_DEPLOYMENT_TARGET"
    cp .build/debug/kai /usr/local/bin/
esac

echo "done"

