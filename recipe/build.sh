#!/bin/bash

set -v -x

# copy unpacked unix_cc_configure for inclusion in the embedded tools zip file
cp tools/cpp/unix_cc_configure.bzl tools/cpp/unix_cc_configure.bzl.orig
patch -p1 < $RECIPE_DIR/0003-statically-link-libstdc.patch

# useful for debugging:
#export BAZEL_BUILD_OPTS="--logging=6 --subcommands --verbose_failures --linkopt=-static-libgcc"
export BAZEL_BUILD_OPTS="--linkopt=-static-libgcc"
sh compile.sh
mv output/bazel $PREFIX/bin

# libstdc++ should not be included in this listing as it is statically linked
readelf -d $PREFIX/bin/bazel
