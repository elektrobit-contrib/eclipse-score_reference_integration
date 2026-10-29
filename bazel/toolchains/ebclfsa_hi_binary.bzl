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

"""Build an executable with the EBcLfSA high-integrity toolchain."""

def _ebclfsa_hi_transition_impl(settings, _attr):
    hi_toolchain = str(Label("//bazel/toolchains:score_ebclfsa_toolchain_hi"))
    return {
        "//command_line_option:platforms": [str(Label("@score_bazel_platforms//:aarch64-linux-sdk_2.0.0-beta3-ebclfsa"))],
        # Both EB toolchains match this platform; prefer HI only in this subtree.
        "//command_line_option:extra_toolchains": [
            toolchain
            for toolchain in settings["//command_line_option:extra_toolchains"]
            if toolchain != hi_toolchain
        ] + [hi_toolchain],
    }

_ebclfsa_hi_transition = transition(
    implementation = _ebclfsa_hi_transition_impl,
    inputs = ["//command_line_option:extra_toolchains"],
    outputs = [
        "//command_line_option:platforms",
        "//command_line_option:extra_toolchains",
    ],
)

def _ebclfsa_hi_binary_impl(ctx):
    binary = ctx.attr.binary[0][DefaultInfo]
    executable = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(
        output = executable,
        target_file = binary.files_to_run.executable,
        is_executable = True,
    )
    return [DefaultInfo(
        executable = executable,
        runfiles = ctx.runfiles(files = [executable]).merge(binary.default_runfiles).merge(binary.data_runfiles),
    )]

ebclfsa_hi_binary = rule(
    implementation = _ebclfsa_hi_binary_impl,
    attrs = {
        "binary": attr.label(
            mandatory = True,
            executable = True,
            cfg = _ebclfsa_hi_transition,
            doc = "Executable and transitive dependencies to build with the HI SDK.",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    executable = True,
)
