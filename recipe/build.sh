#!/bin/bash

set -v -x

# useful for debugging:
#export BAZEL_BUILD_OPTS="--logging=6 --subcommands --verbose_failures --linkopt=-static-libgcc"

# xref: https://github.com/bazelbuild/bazel/blob/0.12.0/tools/cpp/unix_cc_configure.bzl#L257-L258
# xref: https://github.com/bazelbuild/bazel/blob/0.12.0/tools/cpp/lib_cc_configure.bzl#L25-L39
export BAZEL_LINKOPTS="-static-libgcc:-static-libstdc++:-l%:libstdc++.a:-lm:-Wl,--disable-new-dtags"

sh compile.sh
mv output/bazel $PREFIX/bin

if [[ ${HOST} =~ .*linux.* ]]; then
    # libstdc++ should not be included in this listing as it is statically linked
    readelf -d $PREFIX/bin/bazel
fi
