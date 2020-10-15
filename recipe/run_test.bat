@echo on

mkdir tutorial
ROBOCOPY %RECIPE_DIR%\tutorial tutorial /E
cd tutorial
set BAZEL_BUILD_OPTS=""
set "EXTRA_BAZEL_ARGS=--host_javabase=@local_jdk//:jdk"
set "BAZEL_VS=%VSINSTALLDIR%"

bazel build //main:hello-world