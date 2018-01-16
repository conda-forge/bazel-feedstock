# Move the build environment's lib directory to prevent DSOs 
# present there from being used by the bazel binaries. 
# see: https://github.com/conda/conda-build/issues/2625
mv ${BUILD_PREFIX}/lib ${BUILD_PREFIX}/lib_moved

# Test by building an example from the tutorial.
# https://github.com/bazelbuild/examples/
# https://docs.bazel.build/versions/master/tutorial/cpp.html
cp -r ${RECIPE_DIR}/tutorial .
cd tutorial
bazel build --verbose_failures //main:hello-world
