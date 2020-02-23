# Test by building an example from the tutorial.
# https://github.com/bazelbuild/examples/
# https://docs.bazel.build/versions/master/tutorial/cpp.html
set -x

cp -r ${RECIPE_DIR}/tutorial .
cd tutorial
declare -a BAZEL_BUILD_OPTS
bazel build "${BAZEL_BUILD_OPTS[@]}" //main:hello-world
