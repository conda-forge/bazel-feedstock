#!/bin/bash

set -euxo pipefail

# set up bazel config file for conda provided clang toolchain
cp -r ${RECIPE_DIR}/custom_clang_toolchain .
pushd custom_clang_toolchain
  if [[ "${target_platform}" == osx-* ]]; then
    export CONDA_CLANG_VERSION=$($CC -v 2>&1 | head -n1 | cut -d' ' -f3)
    sed -e "s:\${CLANG}:${CLANG}:" \
        -e "s:\${INSTALL_NAME_TOOL}:${INSTALL_NAME_TOOL}:" \
        -e "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" \
        cc_wrapper.sh.template > cc_wrapper.sh
    chmod +x cc_wrapper.sh
    export GCC="cc_wrapper.sh"
    export AR=${LIBTOOL}
  else
    export AR=$(basename ${AR})
    touch cc_wrapper.sh
  fi

  TARGET_SYSTEM="${HOST}"
  if [[ "${target_platform}" == osx-64 ]]; then
    TARGET_CPU="darwin_x86_64"
    TARGET_SYSTEM="x86_64-apple-macosx"
  elif [[ "${target_platform}" == "osx-arm64" ]]; then
    TARGET_CPU="darwin_arm64"
    TARGET_SYSTEM="x86_64-apple-macosx"
  elif [[ "${target_platform}" == "linux-64" ]]; then
    TARGET_CPU="k8"
  elif [[ "${target_platform}" == "linux-aarch64" ]]; then
    TARGET_CPU="arm64"
  elif [[ "${target_platform}" == "linux-ppc64le" ]]; then
    TARGET_CPU="ppc"
  fi
  if [[ "${build_platform}" == osx-64 ]]; then
    BUILD_CPU="darwin_x86_64"
  elif [[ "${build_platform}" == "osx-arm64" ]]; then
    BUILD_CPU="darwin_arm64"
  elif [[ "${build_platform}" == "linux-64" ]]; then
    BUILD_CPU="k8"
  elif [[ "${build_platform}" == "linux-aarch64" ]]; then
    BUILD_CPU="arm64"
  elif [[ "${build_platform}" == "linux-ppc64le" ]]; then
    BUILD_CPU="ppc"
  fi

  sed -ie "s:TARGET_CPU:${TARGET_CPU}:" BUILD
  sed -ie "s:TARGET_CPU:${TARGET_CPU}:" cc_toolchain_config.bzl
  sed -ie "s:TARGET_SYSTEM:${TARGET_SYSTEM}:" cc_toolchain_config.bzl
  sed -ie "s:TARGET_PLATFORM:${target_platform}:" cc_toolchain_config.bzl
  sed -ie "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" cc_toolchain_config.bzl
  sed -ie "s:\${CONDA_CLANG_VERSION}:${CONDA_CLANG_VERSION:-}:" cc_toolchain_config.bzl
  sed -ie "s:\${GCC}:${GCC}:" cc_toolchain_config.bzl
  sed -ie "s:\${PREFIX}:${PREFIX}:" cc_toolchain_config.bzl
  sed -ie "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" cc_toolchain_config.bzl
  sed -ie "s:\${LD}:${LD}:" cc_toolchain_config.bzl
  sed -ie "s:\${CFLAGS}:${CFLAGS}:" cc_toolchain_config.bzl
  sed -ie "s:\${CPPFLAGS}:${CPPFLAGS}:" cc_toolchain_config.bzl
  sed -ie "s:\${CXXFLAGS}:${CXXFLAGS}:" cc_toolchain_config.bzl
  sed -ie "s:\${LDFLAGS}:${LDFLAGS}:" cc_toolchain_config.bzl
  sed -ie "s:\${NM}:${NM}:" cc_toolchain_config.bzl
  sed -ie "s:\${STRIP}:${STRIP}:" cc_toolchain_config.bzl
  sed -ie "s:\${AR}:${AR}:" cc_toolchain_config.bzl
popd
