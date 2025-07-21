#!/bin/bash

set -euxo pipefail

${SRC_DIR}/bazel-${PKG_VERSION}-windows-x86_64.exe --output_base=${SRC_DIR}/out build \
	--cxxopt=/std:c++17 \
	--action_env=PATH \
	--spawn_strategy=standalone \
	--nojava_header_compilation \
	--strategy=Javac=worker \
	--worker_quit_after_build \
	--ignore_unsupported_sandboxing \
	--compilation_mode=opt \
	--enable_bzlmod \
	--check_direct_dependencies=error \
	--lockfile_mode=update \
    src:bazel_nojdk.exe

cp bazel-bin/src/bazel_nojdk.exe ${LIBRARY_PREFIX}/bin/bazel.exe
${SRC_DIR}/bazel-${PKG_VERSION}-windows-x86_64.exe clean --expunge

ls -l
exit 1
