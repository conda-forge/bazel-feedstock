@echo on

cd tutorial
set BAZEL_BUILD_OPTS=""
set "EXTRA_BAZEL_ARGS=--host_javabase=@local_jdk//:jdk"
set "BAZEL_VS=%VSINSTALLDIR%"

bazel build //main:hello-world
bazel clean --expunge
