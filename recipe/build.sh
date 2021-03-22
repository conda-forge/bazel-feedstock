#!/bin/bash

set -euxo pipefail

# useful for debugging:
#export BAZEL_BUILD_OPTS="--logging=6 --subcommands --verbose_failures"
export BAZEL_BUILD_OPTS=""

# Even with the above arguments, subcommands with long argument lists will be
# passed via .params files. These files are automatically removed, even when a build
# fails. To examine these files, remove the cleanup in scripts/bootstrap/buildenv.sh
# By default these files are stored in in /tmp. This can be changed by setting
# the TMPDIR environment variable. It might be necessary to pass
# "--materialize_param_files" to Bazel.

if [[ "${target_platform}" == osx-* ]]; then
  if [[ "${target_platform}" == "osx-64" ]]; then
    if [[ $(basename $CONDA_BUILD_SYSROOT) != "MacOSX10.12.sdk" ]]; then
      echo "WARNING: You asked me to use $CONDA_BUILD_SYSROOT as the MacOS SDK"
      echo "         But because of the use of Objective-C Generics we need at"
      echo "         least MacOSX10.12.sdk"
      CONDA_BUILD_SYSROOT=/opt/MacOSX10.12.sdk
      if [[ ! -d $CONDA_BUILD_SYSROOT ]]; then
        echo "ERROR: $CONDA_BUILD_SYSROOT is not a directory"
        exit 1
      fi
    fi
    export LDFLAGS="${LDFLAGS} -framework IOKit"
  elif [[ "${target_platform}" == "osx-arm64" ]]; then
    export LDFLAGS="${LDFLAGS} -framework IOKit -mmacosx-version-min=11.0"
  fi
  export CONDA_CLANG_VERSION=$($CC -v 2>&1 | head -n1 | cut -d' ' -f3)
  export BAZEL_USE_CPP_ONLY_TOOLCHAIN=1
  export BAZEL_BUILD_OPTS="--logging=6 --subcommands --verbose_failures --crosstool_top=//custom_clang_toolchain:toolchain --define=PROTOBUF_INCLUDE_PATH=${PREFIX}/include"
  export EXTRA_BAZEL_ARGS="--host_javabase=@local_jdk//:jdk"

  sed -i "" "s:\${PREFIX}:${PREFIX}:" src/BUILD
  sed -i "" "s:\${INSTALL_NAME_TOOL}:${INSTALL_NAME_TOOL}:" src/BUILD
  sed -i "" "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" third_party/grpc/BUILD
  sed -i "" "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" third_party/systemlibs/protobuf.BUILD
  sed -i "" "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" third_party/ijar/BUILD

  # set up bazel config file for conda provided clang toolchain
  cp -r ${RECIPE_DIR}/custom_clang_toolchain .
  pushd custom_clang_toolchain
    sed -e "s:\${CLANG}:${CLANG}:" \
        -e "s:\${INSTALL_NAME_TOOL}:${INSTALL_NAME_TOOL}:" \
        -e "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" \
        cc_wrapper.sh.template > cc_wrapper.sh
    chmod +x cc_wrapper.sh
    sed -i "" "s:\${PREFIX}:${PREFIX}:" cc_toolchain_config.bzl
    sed -i "" "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" cc_toolchain_config.bzl
    sed -i "" "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" cc_toolchain_config.bzl
    sed -i "" "s:\${CONDA_CLANG_VERSION}:${CONDA_CLANG_VERSION}:" cc_toolchain_config.bzl
    sed -i "" "s:\${LD}:${LD}:" cc_toolchain_config.bzl
    sed -i "" "s:\${CFLAGS}:${CFLAGS}:" cc_toolchain_config.bzl
    sed -i "" "s:\${CPPFLAGS}:${CPPFLAGS}:" cc_toolchain_config.bzl
    sed -i "" "s:\${CXXFLAGS}:${CXXFLAGS}:" cc_toolchain_config.bzl
    sed -i "" "s:\${LDFLAGS}:${LDFLAGS}:" cc_toolchain_config.bzl
    sed -i "" "s:\${NM}:${NM}:" cc_toolchain_config.bzl
    sed -i "" "s:\${STRIP}:${STRIP}:" cc_toolchain_config.bzl
    sed -i "" "s:\${AR}:${LIBTOOL}:" cc_toolchain_config.bzl
    sed -i "" "s:\${LIBTOOL}:${LIBTOOL}:" cc_toolchain_config.bzl
  popd
  ./compile.sh
  mkdir -p $PREFIX/bin/
  cat <<'EOF' > $PREFIX/bin/bazel
#!/bin/bash

PREFIX_DIR=$(dirname ${BASH_SOURCE})
# Make PREDIX_DIR absolute
if [[ $(uname) == 'Linux' ]]; then
  PREFIX_DIR=$(readlink -f ${PREFIX_DIR})
else
  pushd ${PREFIX_DIR}
  PREFIX_DIR=$(pwd -P)
  popd
fi

# Go one level up
PREFIX_DIR=$(dirname ${PREFIX_DIR})

if [[ "$*" != *"--output_user_root"* ]]; then
  $PREFIX_DIR/bin/bazel-real --output_user_root ${PREFIX_DIR}/share/bazel $*
else
  $PREFIX_DIR/bin/bazel-real $*
fi
EOF
  chmod +x $PREFIX/bin/bazel
  mv output/bazel $PREFIX/bin/bazel-real
  mkdir -p $PREFIX/share/bazel
  $PREFIX/bin/bazel version
  for executable in "build-runfiles" "daemonize" "linux-sandbox" "process-wrapper"; do
    ${INSTALL_NAME_TOOL} -rpath ${PREFIX}/lib '@loader_path/../../../../lib' $PREFIX/share/bazel/install/*/$executable
    # Set timestamps to untampered
    touch -mt $(($(date '+%Y') + 10))10101010 $PREFIX/share/bazel/install/*/$executable
  done
  for i in $PREFIX/share/bazel; do
    if [[ "$i" != "install" ]]; then
	rm -rf "$PREFIX/share/bazel/$i"
    fi
  done
else
    # The bazel binary is a self extracting zip file which contains binaries
    # and libraries, some of which are linked to libstdc++.
    # At runtime a compatible libstdc++ must be available for these libraries
    # and binaries to work.
    # Since the libstdc++ used by conda to build bazel is newer than the one
    # available of some systems, for example CentOS 6, the system cannot be
    # relied upon to provide this library.
    # Typically libstdc++ is dynamically linked to libraries and binaries in
    # conda packages and the RPATH of these files are patched to point to
    # $PREFIX/lib as a relative path.
    # Unfortunately bazel is unpacked outside of the conda environment,
    # so this technique cannot be used.
    # Rather libstdc++ (and libgcc) are statically linked in the binaries and
    # libraries inside of self extracting zip and bazel itself.
    # Another possible technique would be:
    # * Unpack the zip after it is built
    # * Copy libstdc++ and any other libraries into the unpacked directory.
    # * Adjust the RPATH of all binaries and libraries to point to the directory
    #   containing these libraries with a relative path.
    # * Repack the directory as a self extracting zip

    # Linux - set flags for statically linking libstdc++
    # xref: https://github.com/bazelbuild/bazel/blob/0.12.0/tools/cpp/unix_cc_configure.bzl#L257-L258
    # xref: https://github.com/bazelbuild/bazel/blob/0.12.0/tools/cpp/lib_cc_configure.bzl#L25-L39
    export BAZEL_LINKOPTS="-static-libgcc:-static-libstdc++:-l%:libstdc++.a:-lm:-Wl,--disable-new-dtags"
    export EXTRA_BAZEL_ARGS="--host_javabase=@local_jdk//:jdk"

    # -static-libstdc++ only works with g++, gcc ignores the argument.  Bazel
    # uses a single compiler, $CC, to compile and link C and C++. Here we
    # define $CC as a wrapper script which dispatches to g++ if the arguments
    # passes contain a params file or a c++ argument (e.g. --std=c++11).
    # see:
    # https://github.com/bazelbuild/bazel/issues/4644
    # https://github.com/bazelbuild/bazel/issues/2840
    cat > wrapper.sh << EOF
#!/bin/bash
if [[ "\$@" == *"params"* ]] || [[ "\$@" == *"c++"* ]] ; then
    ${GXX} "\$@"
else
    ${GCC} "\$@"
fi
EOF
    chmod +x wrapper.sh
    cp wrapper.sh ${BUILD_PREFIX}/bin/
    export CC=${BUILD_PREFIX}/bin/wrapper.sh
	./compile.sh
	mkdir -p $PREFIX/bin/
	mv output/bazel $PREFIX/bin
fi
