#!/bin/bash

set -euxo pipefail

${SRC_DIR}/bazel-${PKG_VERSION}-windows-x86_64.exe build --cxxopt=/std:c++17 src:bazel_nojdk.exe --action_env=PATH --spawn_strategy=standalone --nojava_header_compilation --strategy=Javac=worker --worker_quit_after_build --ignore_unsupported_sandboxing --compilation_mode=opt --enable_bzlmod --check_direct_dependencies=error --lockfile_mode=update --subcommands --logging=6

