#!/bin/bash

set -euxo pipefail

if [[ "${target_platform}" == "osx-64" ]]; then
  TARGET_CPU="darwin_x86_64"
elif [[ "${target_platform}" == "osx-arm64" ]]; then
  TARGET_CPU="darwin_arm64"
elif [[ "${target_platform}" == "linux-64" ]]; then
  TARGET_CPU="k8"
elif [[ "${target_platform}" == "linux-aarch64" ]]; then
  TARGET_CPU="aarch64"
elif [[ "${target_platform}" == "linux-ppc64le" ]]; then
  TARGET_CPU="ppc"
fi
if [[ "${build_platform}" == "osx-64" ]]; then
  BUILD_CPU="darwin"
elif [[ "${build_platform}" == "osx-arm64" ]]; then
  BUILD_CPU="darwin"
elif [[ "${build_platform}" == "linux-64" ]]; then
  BUILD_CPU="k8"
elif [[ "${build_platform}" == "linux-aarch64" ]]; then
  BUILD_CPU="aarch64"
elif [[ "${build_platform}" == "linux-ppc64le" ]]; then
  BUILD_CPU="ppc"
fi
# The current Bazel release cannot distinguish between osx-arm64 and osx-64.
# This will change with later releases and then we should get rid of this section again.
if [[ "${target_platform}" == osx-* ]]; then
  if [[ "${build_platform}" == "${target_platform}" ]]; then
    TARGET_CPU="darwin"
    BUILD_CPU="darwin"
  fi
fi

export BAZEL_USE_CPP_ONLY_TOOLCHAIN=1
# For debugging purposes, you can add
# --logging=6 --subcommands --verbose_failures
# This is though too much log output for Travis CI.
export BAZEL_BUILD_OPTS="--crosstool_top=//custom_toolchain:toolchain --define=PROTOBUF_INCLUDE_PATH=${PREFIX}/include --cpu=${TARGET_CPU}"
export EXTRA_BAZEL_ARGS="--host_javabase=@local_jdk//:jdk"

sed -ie "s:\${PREFIX}:${PREFIX}:" src/BUILD
sed -ie "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" third_party/grpc/BUILD
sed -ie "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" third_party/systemlibs/protobuf.BUILD
sed -ie "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" third_party/ijar/BUILD
sed -ie "s:TARGET_CPU:${TARGET_CPU}:" compile.sh
sed -ie "s:BUILD_CPU:${BUILD_CPU}:" compile.sh

if [[ "${target_platform}" == osx-* ]]; then
  if [[ "${target_platform}" == "osx-64" ]]; then
    export LDFLAGS="${LDFLAGS} -framework IOKit"
  elif [[ "${target_platform}" == "osx-arm64" ]]; then
    export LDFLAGS="${LDFLAGS} -framework IOKit -mmacosx-version-min=11.0"
  fi

  sed -ie "s:\${INSTALL_NAME_TOOL}:${INSTALL_NAME_TOOL}:" src/BUILD
  ${RECIPE_DIR}/gen-bazel-toolchain.sh

  ./compile.sh
  mkdir -p $PREFIX/bin/
  cp ${RECIPE_DIR}/bazel-osx-wrapper.sh $PREFIX/bin/bazel
  chmod +x $PREFIX/bin/bazel
  mv output/bazel $PREFIX/bin/bazel-real
  mkdir -p $PREFIX/share/bazel/install
  mkdir -p install-archive
  pushd install-archive
    unzip $PREFIX/bin/bazel-real
    export INSTALL_BASE_KEY=$(cat install_base_key)
  popd
  mv install-archive $PREFIX/share/bazel/install/${INSTALL_BASE_KEY}
  chmod -R a+w $PREFIX/share/bazel/install/${INSTALL_BASE_KEY}
  for executable in "build-runfiles" "daemonize" "linux-sandbox" "process-wrapper"; do
    ${INSTALL_NAME_TOOL} -rpath ${PREFIX}/lib '@loader_path/../../../../lib' $PREFIX/share/bazel/install/${INSTALL_BASE_KEY}/$executable
  done
  # Set timestamps to untampered
  find $PREFIX/share/bazel/install/${INSTALL_BASE_KEY} -type f | xargs touch -mt $(($(date '+%Y') + 10))10101010
  chmod -R a-w $PREFIX/share/bazel/install/${INSTALL_BASE_KEY}
else
  export LDFLAGS="${LDFLAGS} -lpthread"
  ${RECIPE_DIR}/gen-bazel-toolchain.sh
  ./compile.sh
  mkdir -p $PREFIX/bin/
  mv output/bazel $PREFIX/bin
fi
