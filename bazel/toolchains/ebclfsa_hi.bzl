# *******************************************************************************
# Copyright (c) 2026 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License Version 2.0 which is available at
# https://www.apache.org/licenses/LICENSE-2.0
#
# SPDX-License-Identifier: Apache-2.0
# *******************************************************************************

"""Clang/musl toolchain for the EBcLfSA high-integrity SDK."""

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl", "action_config", "feature", "flag_group", "flag_set", "tool", "tool_path", "variable_with_value", "with_feature_set")
load("@rules_cc//cc:defs.bzl", "cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

_C = [ACTION_NAMES.c_compile, ACTION_NAMES.preprocess_assemble]
_CXX = [ACTION_NAMES.cpp_compile, ACTION_NAMES.linkstamp_compile]
_LINK = [ACTION_NAMES.cpp_link_executable, ACTION_NAMES.cpp_link_dynamic_library, ACTION_NAMES.cpp_link_nodeps_dynamic_library]

def _flags(name, actions, flags, **kwargs):
    return feature(
        name = name,
        enabled = True,
        flag_sets = [flag_set(actions = actions, flag_groups = [flag_group(flags = flags, **kwargs)])],
    )

def _config_impl(ctx):
    sdk = ctx.file.sdk.dirname
    libcxx = sdk + "/opt/lisa-libcxx"
    clang = sdk + "/usr/lib/llvm-20"
    libc = sdk + "/opt/lisa-libc"
    compile_actions = _C + _CXX
    features = [
        _flags("sdk_c_driver", _C, [ctx.file.cc.path]),
        _flags("sdk_cxx_driver", _CXX + _LINK, [ctx.file.cxx.path]),
        _flags("sdk_ar_driver", [ACTION_NAMES.cpp_link_static_library], [ctx.file.ar.path]),
        _flags("sdk_strip_driver", [ACTION_NAMES.strip], [ctx.file.strip.path]),
        feature(name = "no_legacy_features", enabled = True),
        feature(name = "supports_pic", enabled = True),
        feature(name = "dbg"),
        feature(name = "opt"),
        feature(
            name = "build_mode",
            enabled = True,
            flag_sets = [
                flag_set(
                    actions = compile_actions,
                    flag_groups = [flag_group(flags = ["-g"])],
                    with_features = [with_feature_set(features = ["dbg"])],
                ),
                flag_set(
                    actions = compile_actions,
                    flag_groups = [flag_group(flags = ["-O2", "-DNDEBUG"])],
                    with_features = [with_feature_set(features = ["opt"])],
                ),
            ],
        ),
        _flags("compile_flags", compile_actions, [
            "--target=aarch64-linux-musl",
            "-nostdinc",
            "-fno-omit-frame-pointer",
            "-ffunction-sections",
            "-fdata-sections",
        ]),
        _flags("c_headers", _C, [
            "-isystem",
            libc + "/include",
            "-isystem",
            clang + "/lib/clang/20/include",
        ]),
        _flags("cxx_flags", _CXX, [
            "-std=c++17",
            "-nostdinc++",
            "-isystem",
            libcxx + "/include/c++/v1",
            "-isystem",
            libc + "/include",
            "-isystem",
            clang + "/lib/clang/20/include",
            "-fno-exceptions",
            "-fno-rtti",
        ]),
        _flags("user_compile_flags", compile_actions, ["%{user_compile_flags}"], iterate_over = "user_compile_flags", expand_if_available = "user_compile_flags"),
        _flags("defines", compile_actions, ["-D%{preprocessor_defines}"], iterate_over = "preprocessor_defines", expand_if_available = "preprocessor_defines"),
        _flags("includes", compile_actions, ["-include", "%{includes}"], iterate_over = "includes", expand_if_available = "includes"),
        _flags("include_paths", compile_actions, ["-I%{include_paths}"], iterate_over = "include_paths", expand_if_available = "include_paths"),
        _flags("quote_include_paths", compile_actions, ["-iquote", "%{quote_include_paths}"], iterate_over = "quote_include_paths", expand_if_available = "quote_include_paths"),
        _flags("system_include_paths", compile_actions, ["-isystem", "%{system_include_paths}"], iterate_over = "system_include_paths", expand_if_available = "system_include_paths"),
        _flags("dependency_file", compile_actions, ["-MD", "-MF", "%{dependency_file}"], expand_if_available = "dependency_file"),
        _flags("compiler_input", compile_actions, ["-c", "%{source_file}"], expand_if_available = "source_file"),
        _flags("compiler_output", compile_actions, ["-o", "%{output_file}"], expand_if_available = "output_file"),
        _flags("pic", compile_actions, ["-fPIC"], expand_if_available = "pic"),
        _flags("link_flags", _LINK, [
            "--target=aarch64-linux-musl",
            "--ld-path=" + clang + "/bin/ld.lld",
            "-nostdlib",
            "-static",
            "-Wl,--gc-sections",
        ]),
        _flags("user_link_flags", _LINK, ["%{user_link_flags}"], iterate_over = "user_link_flags", expand_if_available = "user_link_flags"),
        _flags("link_output", _LINK, ["-o", "%{output_execpath}"], expand_if_available = "output_execpath"),
        feature(
            name = "libraries_to_link",
            enabled = True,
            flag_sets = [flag_set(
                actions = _LINK,
                flag_groups = [flag_group(
                    iterate_over = "libraries_to_link",
                    expand_if_available = "libraries_to_link",
                    flag_groups = [
                        flag_group(flags = ["-Wl,--whole-archive"], expand_if_true = "libraries_to_link.is_whole_archive"),
                        flag_group(flags = ["%{libraries_to_link.object_files}"], iterate_over = "libraries_to_link.object_files", expand_if_equal = variable_with_value(name = "libraries_to_link.type", value = "object_file_group")),
                        flag_group(flags = ["%{libraries_to_link.name}"], expand_if_equal = variable_with_value(name = "libraries_to_link.type", value = "object_file")),
                        flag_group(flags = ["%{libraries_to_link.name}"], expand_if_equal = variable_with_value(name = "libraries_to_link.type", value = "static_library")),
                        flag_group(flags = ["-l%{libraries_to_link.name}"], expand_if_equal = variable_with_value(name = "libraries_to_link.type", value = "dynamic_library")),
                        flag_group(flags = ["-l:%{libraries_to_link.name}"], expand_if_equal = variable_with_value(name = "libraries_to_link.type", value = "versioned_dynamic_library")),
                        flag_group(flags = ["-Wl,--no-whole-archive"], expand_if_true = "libraries_to_link.is_whole_archive"),
                    ],
                )],
            )],
        ),
        _flags("runtime", _LINK, [
            "-Wl,--start-group",
            libcxx + "/lib/libc++.a",
            libcxx + "/lib/libc++abi.a",
            clang + "/lib/clang/20/lib/linux/libclang_rt.builtins-aarch64.a",
            libc + "/lib/aarch64-linux-gnu/crt1.o",
            libc + "/lib/aarch64-linux-gnu/libc.a",
            "-Wl,--end-group",
        ]),
        _flags("archive_flags", [ACTION_NAMES.cpp_link_static_library], ["rcsD", "%{output_execpath}"]),
        _flags("strip_flags", [ACTION_NAMES.strip], ["-S", "-o", "%{output_file}", "%{input_file}"]),
        feature(
            name = "archive_objects",
            enabled = True,
            flag_sets = [flag_set(
                actions = [ACTION_NAMES.cpp_link_static_library],
                flag_groups = [flag_group(
                    iterate_over = "libraries_to_link",
                    flag_groups = [
                        flag_group(flags = ["%{libraries_to_link.name}"], expand_if_equal = variable_with_value(name = "libraries_to_link.type", value = "object_file")),
                        flag_group(flags = ["%{libraries_to_link.object_files}"], iterate_over = "libraries_to_link.object_files", expand_if_equal = variable_with_value(name = "libraries_to_link.type", value = "object_file_group")),
                    ],
                )],
            )],
        ),
    ]
    configs = [
        action_config(action_name = action, enabled = True, tools = [tool(tool = ctx.file.driver)])
        for action in compile_actions + _LINK + [ACTION_NAMES.cpp_link_static_library, ACTION_NAMES.strip]
    ]
    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        features = features,
        action_configs = configs,
        cxx_builtin_include_directories = [
            libcxx + "/include/c++/v1",
            libc + "/include",
            clang + "/lib/clang/20/include",
        ],
        toolchain_identifier = "ebclfsa-clang-musl",
        host_system_name = "x86_64-linux",
        target_system_name = "aarch64-linux-musl",
        target_cpu = "aarch64",
        target_libc = "musl",
        compiler = "clang",
        abi_version = "aarch64",
        abi_libc_version = "musl",
        tool_paths = [tool_path(name = "gcov", path = "/bin/false")],
    )

_cc_toolchain_config = rule(
    implementation = _config_impl,
    attrs = {
        "sdk": attr.label(default = "@score_ebclfsa_toolchain_pkg//:BUILD.bazel", allow_single_file = True),
        "cc": attr.label(default = "@score_ebclfsa_toolchain_pkg//:usr/lib/llvm-20/bin/clang", allow_single_file = True),
        "cxx": attr.label(default = "@score_ebclfsa_toolchain_pkg//:usr/lib/llvm-20/bin/clang++", allow_single_file = True),
        "ar": attr.label(default = "@score_ebclfsa_toolchain_pkg//:ar", allow_single_file = True),
        "strip": attr.label(default = "@score_ebclfsa_toolchain_pkg//:strip", allow_single_file = True),
        "driver": attr.label(default = "//bazel/toolchains:ebclfsa_driver.sh", allow_single_file = True),
    },
    provides = [CcToolchainConfigInfo],
)

def ebclfsa_hi_toolchain(name):
    """Declare the EBcLfSA Clang/musl C/C++ toolchain."""
    native.filegroup(
        name = name + "_files",
        srcs = [
            "@score_ebclfsa_toolchain_pkg//:all_files",
            ":ebclfsa_driver.sh",
        ],
    )
    native.filegroup(name = name + "_empty")
    _cc_toolchain_config(name = name + "_config")
    cc_toolchain(
        name = name + "_cc",
        toolchain_config = ":" + name + "_config",
        all_files = ":" + name + "_files",
        ar_files = ":" + name + "_files",
        as_files = ":" + name + "_files",
        compiler_files = ":" + name + "_files",
        dwp_files = ":" + name + "_empty",
        linker_files = ":" + name + "_files",
        objcopy_files = ":" + name + "_empty",
        strip_files = ":" + name + "_files",
        supports_param_files = 1,
    )
    native.toolchain(
        name = name,
        exec_compatible_with = ["@platforms//cpu:x86_64", "@platforms//os:linux"],
        target_compatible_with = [
            "@platforms//cpu:aarch64",
            "@platforms//os:linux",
            "@score_bazel_platforms//version:sdk_2.0.0-beta3",
            "@score_bazel_platforms//runtime_es:ebclfsa",
        ],
        toolchain = ":" + name + "_cc",
        toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
        visibility = ["//visibility:public"],
    )
