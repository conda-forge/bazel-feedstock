#!/bin/bash

set -v -x
./compile.sh
mv output/bazel $PREFIX/bin
