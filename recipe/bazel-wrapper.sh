#!/bin/bash

PREFIX_DIR=$(dirname ${BASH_SOURCE})
# Make PREDIX_DIR absolute
if [[ $(uname) == 'Linux' ]]; then
  PREFIX_DIR=$(readlink -f ${PREFIX_DIR})
else
  cd ${PREFIX_DIR}
  PREFIX_DIR=$(pwd -P)
  cd - &>/dev/null
fi

# Go one level up
PREFIX_DIR=$(dirname ${PREFIX_DIR})

# FIXME: Since migrating to gRPC 1.78.0, we are seeing spurious hangs with
# the client/server setup on macOS. Remove again if those are gone.
if [[ "$*" = *"--version"* ]]; then
  $PREFIX_DIR/bin/bazel-real --batch $*
elif [[ "$*" != *"--output_user_root"* ]]; then
  $PREFIX_DIR/bin/bazel-real --batch --output_user_root ${PREFIX_DIR}/share/bazel $*
else
  $PREFIX_DIR/bin/bazel-real --batch $*
fi

