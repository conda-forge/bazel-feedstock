#!/bin/bash

set -euxo pipefail

if [[ "${target_platform}" == osx-* ]]; then
  export LDFLAGS="${LDFLAGS} -framework IOKit"
  # See also https://gitlab.kitware.com/cmake/cmake/-/issues/25755
  export CFLAGS="${CFLAGS} -fno-define-target-os-macros"
else
  export LDFLAGS="${LDFLAGS} -lpthread -labsl_synchronization -lm"
fi

# Generate toolchain and set necessary environment variables
source gen-bazel-toolchain

# Remove assemble actions from cxx_flags to avoid -stdlib=libc++ being passed
# to assembly compilations, which causes -Werror failures (e.g. in BoringSSL)
for _tc_cfg in bazel_toolchain/cc_toolchain_config.bzl bazel_toolchain/cc_toolchain_build_config.bzl; do
  sed -i'' -e '/cxx_flags = feature/,/^    )/{
    /ACTION_NAMES.assemble,/d
    /ACTION_NAMES.preprocess_assemble,/d
  }' "$_tc_cfg"
done

# Prepare systemlibs defintions
rm -rf third_party/systemlibs/
cp -ap $RECIPE_DIR/systemlibs third_party/

cp -ap $PREFIX/share/bazel/protobuf/bazel third_party/systemlibs/protobuf/
cp -ap $PREFIX/share/bazel/grpc/bazel third_party/systemlibs/grpc/

# TODO: Patch grpc-bazel-rules
sed -i '/^load("\/\/bazel:protobuf\.bzl",/a load("@rules_cc//cc:cc_library.bzl", "cc_library")' third_party/systemlibs/grpc/bazel/cc_grpc_library.bzl
sed -i 's/native.cc_library/cc_library/' third_party/systemlibs/grpc/bazel/cc_grpc_library.bzl
# Make the rules repository-local
sed -i 's/\@com_github_grpc_grpc//' third_party/systemlibs/grpc/bazel/*.bzl

# Bazel 9 removed native proto rules but kept stubs that fail; always use Starlark versions
sed -i 's/if not hasattr(native,.*/if True:/' \
    third_party/systemlibs/protobuf/bazel/cc_proto_library.bzl \
    third_party/systemlibs/protobuf/bazel/java_proto_library.bzl \
    third_party/systemlibs/protobuf/bazel/java_lite_proto_library.bzl \
    third_party/systemlibs/protobuf/bazel/proto_library.bzl


if [[ "${target_platform}" == "osx-64" ]]; then
  export TARGET_CPU="darwin"
fi

# For debugging purposes, you can add
# --logging=6 --subcommands --verbose_failures
# This is though too much log output for Travis CI.
# Extract minor.patch from libprotobuf version, that is the protoc version
# The protobuf-java needs to be manually bumped if necessary
# See https://protobuf.dev/support/version-support/
export PROTOC=$BUILD_PREFIX/bin/protoc
export GRPC_JAVA_PLUGIN=$BUILD_PREFIX/bin/grpc_java_plugin
export ABSEIL_VERSION=$(conda list -p $PREFIX libabseil --fields version | grep -v '#')
export GRPC_VERSION=$(conda list -p $PREFIX libgrpc --fields version | grep -v '#')
export PROTOC_VERSION=$(conda list -p $PREFIX libprotobuf | grep -v '^#' | tr -s ' ' | cut -f 2 -d ' ' | sed -E 's/^[0-9]+\.([0-9]+\.[0-9]+)$/\1/')
export PROTOBUF_JAVA_MAJOR_VERSION="4"
export BAZEL_BUILD_OPTS="--crosstool_top=//bazel_toolchain:toolchain --define=PROTOBUF_INCLUDE_PATH=${PREFIX}/include --cpu=${TARGET_CPU} --cxxopt=-std=c++17"
export BAZEL_BUILD_OPTS="${BAZEL_BUILD_OPTS} --platforms=//bazel_toolchain:target_platform --host_platform=//bazel_toolchain:build_platform --extra_toolchains=//bazel_toolchain:cc_cf_toolchain --extra_toolchains=//bazel_toolchain:cc_cf_host_toolchain --noincompatible_enable_proto_toolchain_resolution"
export EXTRA_BAZEL_ARGS="--tool_java_runtime_version=21 --java_runtime_version=21"

sed -i "s:\${INSTALL_NAME_TOOL}:${INSTALL_NAME_TOOL:-install_name_tool}:" src/BUILD
sed -i "s:\${PREFIX}:${PREFIX}:" src/BUILD
sed -i "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" \
        third_party/grpc/BUILD \
        third_party/grpc-java/BUILD \
        third_party/systemlibs/protobuf/BUILD \
	third_party/systemlibs/protobuf/src/google/protobuf/compiler/BUILD \
	third_party/systemlibs/grpc/BUILD \
	third_party/ijar/BUILD \
        src/tools/singlejar/BUILD
sed -i "s:TARGET_CPU:${TARGET_CPU}:" compile.sh
sed -i "s:BUILD_CPU:${BUILD_CPU}:" compile.sh
sed -i "s:ABSEIL_VERSION:${ABSEIL_VERSION}:" \
    MODULE.bazel \
    third_party/systemlibs/absl/MODULE.bazel \
    third_party/systemlibs/protobuf/MODULE.bazel
sed -i "s:GRPC_VERSION:${GRPC_VERSION}:" \
    MODULE.bazel \
    third_party/systemlibs/grpc/MODULE.bazel
sed -i "s:PROTOC_VERSION:${PROTOC_VERSION}:" \
    MODULE.bazel \
    third_party/systemlibs/protobuf/MODULE.bazel \
    third_party/systemlibs/grpc/MODULE.bazel
sed -i "s:PROTOBUF_JAVA_MAJOR_VERSION:${PROTOBUF_JAVA_MAJOR_VERSION}:" \
    MODULE.bazel \
    third_party/systemlibs/protobuf/MODULE.bazel

./compile.sh

mkdir -p $PREFIX/bin/
cp ${RECIPE_DIR}/bazel-wrapper.sh $PREFIX/bin/bazel
chmod +x $PREFIX/bin/bazel
mv output/bazel $PREFIX/bin/bazel-real

# Explicitly unpack the contents of the bazel binary. This is normally done
# on demand during runtime. Then this is extracted to a random location and
# we cannot fix the RPATHs reliably.
#
# conda's binary relocation logic sadly doesn't work otherwise as
#  * The binaries are zipped into the main executable.
#  * Modifying the binaries changes their mtime and then bazel rejects them
#    as corrupted.
if [[ "${target_platform}" == linux-* ]]; then
  patchelf --set-rpath '$ORIGIN/../lib' $PREFIX/bin/bazel-real
fi
mkdir -p $PREFIX/share/bazel/install
mkdir -p install-archive
pushd install-archive
  unzip $PREFIX/bin/bazel-real
  export INSTALL_BASE_KEY=$(cat install_base_key)
popd
mv install-archive $PREFIX/share/bazel/install/${INSTALL_BASE_KEY}
chmod -R a+w $PREFIX/share/bazel/install/${INSTALL_BASE_KEY}
for executable in "daemonize" "linux-sandbox" "process-wrapper"; do
  if [[ "${target_platform}" == osx-* ]]; then
    ${INSTALL_NAME_TOOL} -rpath ${PREFIX}/lib '@loader_path/../../../../lib' $PREFIX/share/bazel/install/${INSTALL_BASE_KEY}/$executable
  else
    patchelf --set-rpath '$ORIGIN/../../../../lib' $PREFIX/share/bazel/install/${INSTALL_BASE_KEY}/$executable
  fi
done

# Set timestamps to untampered, otherwise bazel will reject the modified files as corrupted.
find $PREFIX/share/bazel/install/${INSTALL_BASE_KEY} -type f | xargs touch -mt $(($(date '+%Y') + 10))10101010
chmod -R a-w $PREFIX/share/bazel/install/${INSTALL_BASE_KEY}

if [[ "${build_platform}" == "${target_platform}" ]]; then
  # Clean up working directory to speedup any conda-build post-processing
  bazel clean --expunge
fi
