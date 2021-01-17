#!/bin/bash

set -v -x

# useful for debugging:
export BAZEL_BUILD_OPTS="--logging=6 --subcommands --verbose_failures"

# Even with the above arguments, subcommands with long argument lists will be
# passed via .params files. These files are automatically removed, even when a build
# fails. To examine these files, remove the cleanup in scripts/bootstrap/buildenv.sh
# By default these files are stored in in /tmp. This can be changed by setting
# the TMPDIR environment variable. It might be necessary to pass
# "--materialize_param_files" to Bazel.

if [[ ${HOST} =~ .*darwin.* ]]; then
    # macOS: set up bazel config file for conda provided clang toolchain
    # CROSSTOOL file contains flags for statically linking libc++
    cp -r ${RECIPE_DIR}/custom_clang_toolchain .
    cd custom_clang_toolchain
    sed -e "s:\${CLANG}:${CLANG}:" \
        -e "s:\${INSTALL_NAME_TOOL}:${INSTALL_NAME_TOOL}:" \
        -e "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" \
        cc_wrapper.sh.template > cc_wrapper.sh
    chmod +x cc_wrapper.sh
    sed -i "" "s:\${PREFIX}:${BUILD_PREFIX}:" cc_toolchain_config.bzl
    sed -i "" "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" cc_toolchain_config.bzl
    sed -i "" "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" cc_toolchain_config.bzl
    sed -i "" "s:\${LD}:${BUILD_PREFIX}/bin/${LD}:" cc_toolchain_config.bzl
    sed -i "" "s:\${NM}:${BUILD_PREFIX}/bin/${NM}:" cc_toolchain_config.bzl
    sed -i "" "s:\${STRIP}:${BUILD_PREFIX}/bin/${STRIP}:" cc_toolchain_config.bzl
    sed -i "" "s:\${LIBTOOL}:${BUILD_PREFIX}/bin/${LIBTOOL}:" cc_toolchain_config.bzl
    cd ..
    export BAZEL_USE_CPP_ONLY_TOOLCHAIN=1
    export BAZEL_BUILD_OPTS="--verbose_failures --crosstool_top=//custom_clang_toolchain:toolchain"
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
fi

./compile.sh
mv output/bazel $PREFIX/bin

if [[ ${HOST} =~ .*linux.* ]]; then
    # libstdc++ should not be included in this listing as it is statically linked
    readelf -d $PREFIX/bin/bazel
fi
