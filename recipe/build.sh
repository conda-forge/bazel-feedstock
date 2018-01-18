#!/bin/bash

set -v -x

if [[ ${HOST} =~ .*linux.* ]]; then
    # copy unpatched unix_cc_configure for inclusion in the embedded tools zip file
    cp tools/cpp/unix_cc_configure.bzl tools/cpp/unix_cc_configure.bzl.orig
    patch -p1 < $RECIPE_DIR/0003-statically-link-libstdc.patch
fi

# useful for debugging:
#export BAZEL_BUILD_OPTS="--logging=6 --subcommands --verbose_failures --linkopt=-static-libgcc"
if [[ ${HOST} =~ .*darwin.* ]]; then
    export BAZEL_BUILD_OPTS=""
else
    export BAZEL_BUILD_OPTS="--linkopt=-static-libgcc"
fi
sh compile.sh
mv output/bazel $PREFIX/bin

if [[ ${HOST} =~ .*linux.* ]]; then
    # libstdc++ should not be included in this listing as it is statically linked
    readelf -d $PREFIX/bin/bazel
fi
