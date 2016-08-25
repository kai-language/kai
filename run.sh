#!/bin/bash

./build.sh

if [ $? -ne 0 ]; then

  echo "Build Failed!"
  exit 1
fi

.build/debug/kai

