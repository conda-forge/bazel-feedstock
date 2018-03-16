# Test by building an example from the tutorial.
# https://github.com/bazelbuild/examples/
# https://docs.bazel.build/versions/master/tutorial/cpp.html
cp -r ${RECIPE_DIR}/tutorial .
cd tutorial
bazel build --verbose_failures //main:hello-world
