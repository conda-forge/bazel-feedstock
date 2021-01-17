# Test by building an example from the tutorial.
# https://github.com/bazelbuild/examples/
# https://docs.bazel.build/versions/master/tutorial/cpp.html
set -x

cp -r ${RECIPE_DIR}/tutorial .
cd tutorial
declare -a BAZEL_BUILD_OPTS
if [[ ${HOST} =~ .*darwin.* ]]; then
    cp -r ${RECIPE_DIR}/custom_clang_toolchain .
    cd custom_clang_toolchain
    sed -e "s:\${CLANG}:${CLANG}:" \
        -e "s:\${INSTALL_NAME_TOOL}:${INSTALL_NAME_TOOL}:" \
        -e "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" \
        cc_wrapper.sh.template > cc_wrapper.sh
    chmod +x cc_wrapper.sh
    sed -i "" "s:\${PREFIX}:${BUILD_PREFIX}:" cc_toolchain_config.bzl
    sed -i "" "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" cc_toolchain_config.bzl
    sed -i "" "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" cc_toolchain_config.bzl
    sed -i "" "s:\${LD}:${LD}:" cc_toolchain_config.bzl
    sed -i "" "s:\${NM}:${NM}:" cc_toolchain_config.bzl
    sed -i "" "s:\${STRIP}:${STRIP}:" cc_toolchain_config.bzl
    sed -i "" "s:\${LIBTOOL}:${LIBTOOL}:" cc_toolchain_config.bzl
    cd ..
    BAZEL_BUILD_OPTS+=(--cxxopt=-isysroot$CONDA_BUILD_SYSROOT)
#    BAZEL_BUILD_OPTS+=(--verbose_failures)
#    BAZEL_BUILD_OPTS+=(--logging=6 --subcommands)
    BAZEL_BUILD_OPTS+=(--crosstool_top=//custom_clang_toolchain:toolchain)
fi
bazel build "${BAZEL_BUILD_OPTS[@]}" //main:hello-world
