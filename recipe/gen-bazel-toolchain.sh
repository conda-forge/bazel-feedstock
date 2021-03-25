#!/bin/bash

set -euxo pipefail

function apply_cc_template() {
  sed -ie "s:TARGET_CPU:${TARGET_CPU}:" $1
  sed -ie "s:TARGET_LIBC:${TARGET_LIBC}:" $1
  sed -ie "s:TARGET_SYSTEM:${TARGET_SYSTEM}:" $1
  sed -ie "s:TARGET_PLATFORM:${target_platform}:" $1
  sed -ie "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" $1
  sed -ie "s:\${COMPILER_VERSION}:${COMPILER_VERSION:-}:" $1
  sed -ie "s:\${GCC}:${GCC}:" $1
  sed -ie "s:\${PREFIX}:${PREFIX}:" $1
  sed -ie "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" $1
  sed -ie "s:\${LD}:${LD}:" $1
  sed -ie "s:\${CFLAGS}:${CFLAGS}:" $1
  sed -ie "s:\${CPPFLAGS}:${CPPFLAGS}:" $1
  sed -ie "s:\${CXXFLAGS}:${CXXFLAGS}:" $1
  sed -ie "s:\${LDFLAGS}:${LDFLAGS}:" $1
  sed -ie "s:\${NM}:${NM}:" $1
  sed -ie "s:\${STRIP}:${STRIP}:" $1
  sed -ie "s:\${AR}:${AR}:" $1
  sed -ie "s:\${HOST}:${HOST}:" $1
  sed -ie "s:\${LIBCXX}:${LIBCXX}:" $1
}

# set up bazel config file for conda provided clang toolchain
cp -r ${RECIPE_DIR}/custom_toolchain .
pushd custom_toolchain
  if [[ "${target_platform}" == osx-* ]]; then
    export COMPILER_VERSION=$($CC -v 2>&1 | head -n1 | cut -d' ' -f3)
    sed -e "s:\${CLANG}:${CLANG}:" \
        -e "s:\${INSTALL_NAME_TOOL}:${INSTALL_NAME_TOOL}:" \
        -e "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" \
        cc_wrapper.sh.template > cc_wrapper.sh
    chmod +x cc_wrapper.sh
    sed -e "s:\${CLANG}:${CC_FOR_BUILD}:" \
        -e "s:\${INSTALL_NAME_TOOL}:${INSTALL_NAME_TOOL//${HOST}/${BUILD}}:" \
        -e "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" \
        cc_wrapper.sh.template > cc_wrapper_build.sh
    chmod +x cc_wrapper.sh
    export GCC="cc_wrapper.sh"
    export GCC="cc_wrapper.sh"
    export LIBCXX="c++"
    export AR=${LIBTOOL}
  else
    export COMPILER_VERSION=$(${CC} -v 2>&1|tail -n1|cut -d' ' -f3)
    export AR=$(basename ${AR})
    touch cc_wrapper.sh
    export LIBCXX="stdc++"
  fi

  TARGET_SYSTEM="${HOST}"
  if [[ "${target_platform}" == "osx-64" ]]; then
    TARGET_LIBC="macosx"
    TARGET_CPU="darwin_x86_64"
    TARGET_SYSTEM="x86_64-apple-macosx"
  elif [[ "${target_platform}" == "osx-arm64" ]]; then
    TARGET_LIBC="macosx"
    TARGET_CPU="darwin_arm64"
    TARGET_SYSTEM="arm64-apple-macosx"
  elif [[ "${target_platform}" == "linux-64" ]]; then
    TARGET_LIBC="unknown"
    TARGET_CPU="k8"
  elif [[ "${target_platform}" == "linux-aarch64" ]]; then
    TARGET_LIBC="unknown"
    TARGET_CPU="aarch64"
  elif [[ "${target_platform}" == "linux-ppc64le" ]]; then
    TARGET_LIBC="unknown"
    TARGET_CPU="ppc"
  fi
  BUILD_SYSTEM=${BUILD}
  if [[ "${build_platform}" == "osx-64" ]]; then
    BUILD_CPU="darwin"
    BUILD_SYSTEM="x86_64-apple-macosx"
  elif [[ "${build_platform}" == "osx-arm64" ]]; then
    BUILD_CPU="darwin"
    BUILD_SYSTEM="arm64-apple-macosx"
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
  
  sed -ie "s:TARGET_CPU:${TARGET_CPU}:" BUILD
  sed -ie "s:BUILD_CPU:${BUILD_CPU}:" BUILD

  cp cc_toolchain_config.bzl cc_toolchain_build_config.bzl
  apply_cc_template cc_toolchain_config.bzl
  (
    if [[ "${build_platform}" != "${target_platform}" ]]; then
      if [[ "${target_platform}" == osx-* ]]; then
        GCC=cc_wrapper_build.sh
      else
        GCC=${GCC//${HOST}/${BUILD}}
      fi
      TARGET_CPU=${BUILD_CPU}
      TARGET_SYSTEM=${BUILD_SYSTEM}
      TARGET_PLATFORM=${build_platform}
      PREFIX=${BUILD_PREFIX}
      LD=${LD//${HOST}/${BUILD}}
      CFLAGS=${CFLAGS//${PREFIX}/${BUILD_PREFIX}}
      CPPFLAGS=${CPPFLAGS//${PREFIX}/${BUILD_PREFIX}}
      CXXFLAGS=${CXXFLAGS//${PREFIX}/${BUILD_PREFIX}}
      LDFLAGS=${LDFLAGS//${PREFIX}/${BUILD_PREFIX}}
      NM=${NM//${HOST}/${BUILD}}
      STRIP=${STRIP//${HOST}/${BUILD}}
      AR=${AR//${HOST}/${BUILD}}
      HOST=${BUILD}
    fi
    apply_cc_template cc_toolchain_build_config.bzl
  )
popd
