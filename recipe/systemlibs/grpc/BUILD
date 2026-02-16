load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

cc_library(
    name = "grpc",
    linkopts = [
        "-lgrpc",
        "-lgpr",
    ],
    visibility = ["//visibility:public"],
)

cc_library(
    name = "grpc++",
    linkopts = [
        "-lgrpc++",
        "-lgrpc",
        "-lgpr",
    ],
    visibility = ["//visibility:public"],
)

cc_library(
    name = "grpc++_codegen_proto",
    visibility = ["//visibility:public"],
)

cc_library(
    name = "grpc_unsecure",
    linkopts = [
        "-lgrpc_unsecure",
        "-lgpr",
    ],
    visibility = ["//visibility:public"],
)

cc_library(
    name = "grpc++_unsecure",
    linkopts = [
        "-lgrpc++_unsecure",
        "-lgrpc_unsecure",
        "-lgpr",
    ],
    visibility = ["//visibility:public"],
)

genrule(
    name = "ln_grpc_cpp_plugin",
    outs = ["grpc_cpp_plugin.bin"],
    cmd = "ln -s ${BUILD_PREFIX}/bin/grpc_cpp_plugin $@",
)

sh_binary(
    name = "grpc_cpp_plugin",
    srcs = ["grpc_cpp_plugin.bin"],
    visibility = ["//visibility:public"],
)

genrule(
    name = "ln_grpc_python_plugin",
    outs = ["grpc_python_plugin.bin"],
    cmd = "ln -s ${BUILD_PREFIX}/bin/grpc_python_plugin $@",
)

sh_binary(
    name = "grpc_python_plugin",
    srcs = ["grpc_python_plugin.bin"],
    visibility = ["//visibility:public"],
)
