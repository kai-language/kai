#!/bin/bash

./build.sh

if [ $? -ne 0 ]; then

  echo "Build Failed!"
  echo
  exit 1
fi

.build/debug/kai

echo

