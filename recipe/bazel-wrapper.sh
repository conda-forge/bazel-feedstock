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

if [[ "$*" != *"--output_user_root"* ]]; then
  $PREFIX_DIR/bin/bazel-real --output_user_root ${PREFIX_DIR}/share/bazel $*
else
  $PREFIX_DIR/bin/bazel-real $*
fi

