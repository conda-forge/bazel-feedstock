# Test by building an example from the tutorial.
# https://github.com/bazelbuild/examples/
# https://docs.bazel.build/versions/master/tutorial/cpp.html
set -exuo pipefail

cp -r ${RECIPE_DIR}/tutorial .
cd tutorial
bazel build --logging=6 --subcommands --verbose_failures //main:hello-world
