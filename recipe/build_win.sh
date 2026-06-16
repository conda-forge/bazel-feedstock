#!/bin/bash

set -euxo pipefail

# Prepare systemlibs definitions
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

# Set version environment variables
# conda is not available in bash on Windows, so extract versions from conda-meta JSON files
export PROTOC=$BUILD_PREFIX/Library/bin/protoc.exe
export ABSEIL_VERSION=$(grep -o '"version": "[^"]*"' "$PREFIX/conda-meta"/libabseil-*.json | head -1 | sed 's/.*"version": "\(.*\)"/\1/')
export GRPC_VERSION=$(grep -o '"version": "[^"]*"' "$PREFIX/conda-meta"/libgrpc-*.json | head -1 | sed 's/.*"version": "\(.*\)"/\1/' | sed -E 's/^([0-9]+\.[0-9]+)\.[0-9]+$/\1.0/')
export PROTOC_VERSION=$(grep -o '"version": "[^"]*"' "$PREFIX/conda-meta"/libprotobuf-*.json | head -1 | sed 's/.*"version": "\(.*\)"/\1/' | sed -E 's/^[0-9]+\.([0-9]+\.[0-9]+)$/\1/')
export PROTOBUF_JAVA_MAJOR_VERSION="4"
export BAZEL_BUILD_OPTS="--define=PROTOBUF_INCLUDE_PATH=${PREFIX}/include --cxxopt=/std:c++17"

# On Windows, system binaries are in $BUILD_PREFIX/Library/bin/ but genrules
# expect them at $BUILD_PREFIX/bin/. Create symlinks/copies at the expected locations.
# Also, genrules use ln -s which creates msys2 symlinks that Windows-native bazel
# cannot follow. So we create real copies and patch genrules to use cp instead.
mkdir -p $BUILD_PREFIX/bin
cp -a $BUILD_PREFIX/Library/bin/protoc.exe $BUILD_PREFIX/bin/protoc
cp -a $BUILD_PREFIX/Library/bin/grpc_cpp_plugin.exe $BUILD_PREFIX/bin/grpc_cpp_plugin
cp -a $BUILD_PREFIX/Library/bin/grpc_python_plugin.exe $BUILD_PREFIX/bin/grpc_python_plugin

# Patch genrules to use cp instead of ln -s (ln -s creates msys2 symlinks which
# Windows-native bazel cannot follow; cp creates real files)
sed -i 's/ln -s /cp /g' \
    third_party/grpc/BUILD \
    third_party/systemlibs/protobuf/BUILD \
    third_party/systemlibs/protobuf/src/google/protobuf/compiler/BUILD \
    third_party/systemlibs/grpc/BUILD
# For link_proto_files genrule, use cp instead of ln -sf
sed -i 's/ln -sf /cp /g' third_party/systemlibs/protobuf/BUILD
# On Windows, executables need .exe extension; change output names from .bin/.out to .exe
sed -i 's/outs = \["protoc.bin"\]/outs = ["protoc.exe"]/g' third_party/systemlibs/protobuf/BUILD
sed -i 's/outs = \["grpc_cpp_plugin.bin"\]/outs = ["grpc_cpp_plugin.exe"]/g' third_party/systemlibs/grpc/BUILD
sed -i 's/outs = \["grpc_python_plugin.bin"\]/outs = ["grpc_python_plugin.exe"]/g' third_party/systemlibs/grpc/BUILD
sed -i 's/outs = \["grpc-cpp-plugin.out"\]/outs = ["grpc-cpp-plugin.exe"]/g' third_party/grpc/BUILD

# Substitute placeholder paths and versions in BUILD and MODULE files
# On Windows, BUILD_PREFIX is a Windows-native path (e.g. C:\bld\...). Convert to
# cygwin path (e.g. /c/bld/...) to avoid issues with colons and backslashes in sed.
BUILD_PREFIX_CYG=$(cygpath -u "$BUILD_PREFIX")
sed -i "s|\${BUILD_PREFIX}|${BUILD_PREFIX_CYG}|" \
    third_party/grpc/BUILD \
    third_party/systemlibs/protobuf/BUILD \
    third_party/systemlibs/protobuf/src/google/protobuf/compiler/BUILD \
    third_party/systemlibs/grpc/BUILD

sed -i "s|ABSEIL_VERSION|${ABSEIL_VERSION}|" \
    MODULE.bazel \
    third_party/systemlibs/absl/MODULE.bazel \
    third_party/systemlibs/protobuf/MODULE.bazel
sed -i "s|GRPC_VERSION|${GRPC_VERSION}|" \
    MODULE.bazel \
    third_party/systemlibs/grpc/MODULE.bazel
cp -a ${SRC_DIR}/maven_install.json third_party/systemlibs/protobuf/
cat <<'EOF' | "${BUILD_PREFIX_CYG}/Library/bin/python.exe" -
import sys

with open("third_party/systemlibs/protobuf/MODULE.bazel", "r") as f:
    content = f.read()

old_section = """maven_protobuf = use_extension("@rules_jvm_external//:extensions.bzl", "maven")
maven_protobuf.install(
    name = "maven_protobuf",
    artifacts = [
        # keep sorted
        "com.google.protobuf:protobuf-java:PROTOBUF_JAVA_MAJOR_VERSION.PROTOC_VERSION",
        "com.google.protobuf:protobuf-java-util:PROTOBUF_JAVA_MAJOR_VERSION.PROTOC_VERSION",
    ],
    fail_if_repin_required = False,
    repositories = [
        "https://repo1.maven.org/maven2",
    ],
    strict_visibility = False,
    strict_visibility_value = ["//visibility:public"],
)

use_repo(maven_protobuf, "maven_protobuf")"""

new_section = """# Use shared maven repository with same lock file as upstream protobuf module
maven = use_extension("@rules_jvm_external//:extensions.bzl", "maven")
maven.install(
    artifacts = [
        # keep sorted; match upstream protobuf 33.4 PROTOBUF_MAVEN_ARTIFACTS
        "com.google.code.findbugs:jsr305:3.0.2",
        "com.google.code.gson:gson:2.8.9",
        "com.google.errorprone:error_prone_annotations:2.5.1",
        "com.google.guava:guava:32.0.1-jre",
        "com.google.j2objc:j2objc-annotations:2.8",
        "com.google.protobuf:protobuf-java:PROTOBUF_JAVA_MAJOR_VERSION.PROTOC_VERSION",
        "com.google.protobuf:protobuf-java-util:PROTOBUF_JAVA_MAJOR_VERSION.PROTOC_VERSION",
    ],
    lock_file = "//:maven_install.json",
    repositories = [
        "https://repo1.maven.org/maven2",
    ],
)

use_repo(maven, "maven")"""

content = content.replace(old_section, new_section)
with open("third_party/systemlibs/protobuf/MODULE.bazel", "w") as f:
    f.write(content)
print("Updated MODULE.bazel successfully")
EOF

sed -i "s|PROTOC_VERSION|${PROTOC_VERSION}|" \
    MODULE.bazel \
    third_party/systemlibs/protobuf/MODULE.bazel \
    third_party/systemlibs/grpc/MODULE.bazel

sed -i "s|PROTOBUF_JAVA_MAJOR_VERSION|${PROTOBUF_JAVA_MAJOR_VERSION}|" \
    MODULE.bazel \
    third_party/systemlibs/protobuf/MODULE.bazel

${SRC_DIR}/bazel-${PKG_VERSION}-windows-x86_64.exe --output_base=${SRC_DIR}/out build \
	${BAZEL_BUILD_OPTS} \
	--action_env=PATH \
	--nojava_header_compilation \
	--compilation_mode=opt \
	--enable_bzlmod \
	--check_direct_dependencies=error \
	--lockfile_mode=update \
	--discard_analysis_cache \
	--nokeep_state_after_build \
	--notrack_incremental_state \
	--spawn_strategy=worker \
	--strategy=Javac=worker \
	--strategy=CppCompile=worker \
	--worker_quit_after_build \
    src:bazel_nojdk.exe

cp bazel-bin/src/bazel_nojdk.exe ${LIBRARY_PREFIX}/bin/bazel.exe
${SRC_DIR}/bazel-${PKG_VERSION}-windows-x86_64.exe clean --expunge
