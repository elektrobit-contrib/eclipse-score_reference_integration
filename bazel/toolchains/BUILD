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
load("@rules_cc//cc:defs.bzl", "cc_binary")
load("@rules_pkg//pkg:deb.bzl", "pkg_deb")
load("@rules_pkg//pkg:mappings.bzl", "pkg_attributes", "pkg_files")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")
load("@score_tooling//cpp/libclang:libclang_toolchain.bzl", "libclang_toolchain")
load(":ebclfsa_hi.bzl", "ebclfsa_hi_toolchain")
load(":ebclfsa_hi_binary.bzl", "ebclfsa_hi_binary")

ebclfsa_hi_toolchain(name = "score_ebclfsa_toolchain_hi")

cc_binary(
    name = "hello_world_hi",
    srcs = ["hello_world_hi.cc"],
    visibility = ["//visibility:public"],
)

ebclfsa_hi_binary(
    name = "hello_world_hi_for_image",
    binary = ":hello_world_hi",
)

pkg_files(
    name = "hello_world_hi_pkg_files",
    srcs = [":hello_world_hi_for_image"],
    attributes = pkg_attributes(mode = "0755"),
    prefix = "usr/bin",
    renames = {":hello_world_hi_for_image": "hello_world_hi"},
)

pkg_tar(
    name = "hello_world_hi_pkg_tar",
    srcs = [":hello_world_hi_pkg_files"],
)

pkg_deb(
    name = "hello_world_hi_deb",
    architecture = "arm64",
    data = ":hello_world_hi_pkg_tar",
    description = "EBcLfSA high-integrity Clang/musl hello world",
    homepage = "https://github.com/eclipse-score/reference_integration",
    maintainer = "Eclipse S-CORE contributors <score-dev@eclipse.org>",
    package = "score-hello-world-hi",
    version = "1.0",
    visibility = ["//visibility:public"],
)

# libclang toolchain for the score_tooling C++ parser. score_tooling deliberately
# does not register a libclang toolchain for its consumers, so the reference
# integration provides and registers its own (see .bazelrc --extra_toolchains).
# It wraps the LLVM installation declared in
# //bazel_common:score_llvm_libclang.MODULE.bazel.
libclang_toolchain(
    name = "score_ref_int_libclang",
    cc_toolchain = "@llvm_toolchain//:cc-clang-x86_64-linux",
    libclang = "@llvm_toolchain_llvm//:lib/libclang.so",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "score_ref_int_libclang_toolchain",
    toolchain = ":score_ref_int_libclang",
    toolchain_type = "@score_tooling//cpp/libclang:libclang_toolchain_type",
    visibility = ["//visibility:public"],
)
