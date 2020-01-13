#!/bin/bash

set -v -x
./compile.sh
mkdir -p $PREFIX/bin/
cp output/bazel $PREFIX/bin/
