#!/bin/bash

set -e

case "$1" in
xcode)
    swift package generate-xcodeproj 
;;

sourcery)
    ./tools/genAccessors.sh
;;
release)
    MACOSX_DEPLOYMENT_TARGET=10.12
    swift build -Xswiftc -DDEBUG -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx10.12" -c release
    cp .build/release/kai /usr/local/bin/
;;
distribute)
    TAG=$(git describe --abbrev=0 --tags);
    git checkout $TAG;
    cat ./Sources/Core/Options.swift | \
        awk -v tag="$TAG" '/public static let version = "0.0.0"/ { printf "    public static let version = \"%s\"\n", tag; next } 1' > .tmp && \
    mv .tmp ./Sources/Core/Options.swift;

    swift build -c release -Xswiftc -static-stdlib -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx10.12";

    PACKAGE_NAME="kai-$TAG"
    mkdir -p ./$PACKAGE_NAME
    cp .build/release/kai ./$PACKAGE_NAME/kai
    tar -cvzf macOS-sierra.tar.gz ./$PACKAGE_NAME
    rm -rf $PACKAGE_NAME
    git reset --hard HEAD
;;
*)
    MACOSX_DEPLOYMENT_TARGET=10.12
    swift build -Xswiftc -DDEBUG -Xswiftc -DDEVELOPER -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx10.12"
    cp .build/debug/kai /usr/local/bin/
esac

echo "done"

