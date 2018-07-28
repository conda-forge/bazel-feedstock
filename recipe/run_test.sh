# Test by building an example from the tutorial.
# https://github.com/bazelbuild/examples/
# https://docs.bazel.build/versions/master/tutorial/cpp.html
set -x

declare -a BAZEL_BUILD_OPTS
if [[ ${HOST} =~ .*darwin.* ]]; then
    BAZEL_BUILD_OPTS+=(--cxxopt=-isysroot$CONDA_BUILD_SYSROOT)
#    BAZEL_BUILD_OPTS+=(--verbose_failures)
#    BAZEL_BUILD_OPTS+=(--logging=6 --subcommands)
fi
cp -r ${RECIPE_DIR}/tutorial .
cd tutorial
bazel build "${BAZEL_BUILD_OPTS[@]}" //main:hello-world
