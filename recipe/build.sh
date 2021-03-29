#!/bin/bash

set -euxo pipefail

if [[ "${target_platform}" == osx-64 ]]; then
  export LDFLAGS="${LDFLAGS} -framework IOKit"
elif [[ "${target_platform}" == "osx-arm64" ]]; then
  export LDFLAGS="${LDFLAGS} -framework IOKit -mmacosx-version-min=11.0"
else
  export LDFLAGS="${LDFLAGS} -lpthread"
fi

# Generate toolchain and set necessary environment variables
source ${RECIPE_DIR}/gen-bazel-toolchain.sh

# For debugging purposes, you can add
# --logging=6 --subcommands --verbose_failures
# This is though too much log output for Travis CI.
export BAZEL_BUILD_OPTS="--crosstool_top=//custom_toolchain:toolchain --define=PROTOBUF_INCLUDE_PATH=${PREFIX}/include --cpu=${TARGET_CPU}"
export EXTRA_BAZEL_ARGS="--host_javabase=@local_jdk//:jdk"
sed -ie "s:\${INSTALL_NAME_TOOL}:${INSTALL_NAME_TOOL:-install_name_tool}:" src/BUILD
sed -ie "s:\${PREFIX}:${PREFIX}:" src/BUILD
sed -ie "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" third_party/grpc/BUILD
sed -ie "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" third_party/systemlibs/protobuf.BUILD
sed -ie "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" third_party/ijar/BUILD
sed -ie "s:TARGET_CPU:${TARGET_CPU}:" compile.sh
sed -ie "s:BUILD_CPU:${BUILD_CPU}:" compile.sh

./compile.sh

mkdir -p $PREFIX/bin/
cp ${RECIPE_DIR}/bazel-wrapper.sh $PREFIX/bin/bazel
chmod +x $PREFIX/bin/bazel
mv output/bazel $PREFIX/bin/bazel-real
if [[ "${target_platform}" == linux-* ]]; then
  chrpath -r '$ORIGIN/../lib' $PREFIX/bin/bazel-real
fi
mkdir -p $PREFIX/share/bazel/install
mkdir -p install-archive
pushd install-archive
  unzip $PREFIX/bin/bazel-real
  export INSTALL_BASE_KEY=$(cat install_base_key)
popd
mv install-archive $PREFIX/share/bazel/install/${INSTALL_BASE_KEY}
chmod -R a+w $PREFIX/share/bazel/install/${INSTALL_BASE_KEY}
for executable in "build-runfiles" "daemonize" "linux-sandbox" "process-wrapper"; do
  if [[ "${target_platform}" == osx-* ]]; then
    ${INSTALL_NAME_TOOL} -rpath ${PREFIX}/lib '@loader_path/../../../../lib' $PREFIX/share/bazel/install/${INSTALL_BASE_KEY}/$executable
  else
    chrpath -r '$ORIGIN/../../../../lib' $PREFIX/share/bazel/install/${INSTALL_BASE_KEY}/$executable
  fi
done
if [[ "${target_platform}" == osx-* ]]; then
  ${INSTALL_NAME_TOOL} -rpath ${PREFIX}/lib '@loader_path/../../../../../../../../lib' $PREFIX/share/bazel/install/${INSTALL_BASE_KEY}/embedded_tools/tools/zip/zipper/zipper
else
  chrpath -r '$ORIGIN/../../../../../../../../lib' $PREFIX/share/bazel/install/${INSTALL_BASE_KEY}/embedded_tools/tools/zip/zipper/zipper
fi
# Set timestamps to untampered
find $PREFIX/share/bazel/install/${INSTALL_BASE_KEY} -type f | xargs touch -mt $(($(date '+%Y') + 10))10101010
chmod -R a-w $PREFIX/share/bazel/install/${INSTALL_BASE_KEY}
