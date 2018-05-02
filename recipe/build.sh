#!/bin/bash

set -v -x

# useful for debugging:
#export BAZEL_BUILD_OPTS="--logging=6 --subcommands --verbose_failures"

if [[ ${HOST} =~ .*darwin.* ]]; then
    # macOS: set up bazel config file for conda provided clang toolchain
    # CROSSTOOL file contains flags for statically linking libc++
    cp -r ${RECIPE_DIR}/custom_clang_toolchain .
    cd custom_clang_toolchain
    sed -e "s:\${CLANG}:${CLANG}:" \
        -e "s:\${INSTALL_NAME_TOOL}:${INSTALL_NAME_TOOL}:" \
        -e "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" \
        cc_wrapper.sh.template > cc_wrapper.sh
    chmod +x cc_wrapper.sh
    sed -e "s:\${PREFIX}:${BUILD_PREFIX}:" \
        -e "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" \
        -e "s:\${LD}:${LD}:" \
        -e "s:\${NM}:${NM}:" \
        -e "s:\${STRIP}:${STRIP}:" \
        -e "s:\${LIBTOOL}:${LIBTOOL}:" \
        -e "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" \
        CROSSTOOL.template > CROSSTOOL
    cd ..
    export BAZEL_USE_CPP_ONLY_TOOLCHAIN=1
    export BAZEL_BUILD_OPTS="--verbose_failures --crosstool_top=//custom_clang_toolchain:toolchain"
else
    # Linux - set flags for statically linking libstdc++
    # xref: https://github.com/bazelbuild/bazel/blob/0.12.0/tools/cpp/unix_cc_configure.bzl#L257-L258
    # xref: https://github.com/bazelbuild/bazel/blob/0.12.0/tools/cpp/lib_cc_configure.bzl#L25-L39
    export BAZEL_LINKOPTS="-static-libgcc:-static-libstdc++:-l%:libstdc++.a:-lm:-Wl,--disable-new-dtags"
fi

sh compile.sh
mv output/bazel $PREFIX/bin

if [[ ${HOST} =~ .*linux.* ]]; then
    # libstdc++ should not be included in this listing as it is statically linked
    readelf -d $PREFIX/bin/bazel
fi
