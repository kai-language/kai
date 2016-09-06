#!/bin/bash

./build.sh

if [ $? -ne 0 ]; then

  echo "Build Failed!"
  exit 1
fi

if [ -z "$1" ]; then

  .build/debug/kai sample.kai
else

  .build/debug/kai $1
fi
