# *******************************************************************************
# Copyright (c) 2025 Contributors to the Eclipse Foundation
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

load("@rules_pkg//pkg:deb.bzl", "pkg_deb")
load("@rules_pkg//pkg:mappings.bzl", "pkg_attributes", "pkg_files")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")
load("@score_os_images//ebclfsa_aarch64_prebuild:defs.bzl", "ebclfsa_aarch64_prebuild")

pkg_files(
    name = "hello_world_hi_pkg_files",
    srcs = ["//bazel/toolchains:hello_world_hi_for_image"],
    attributes = pkg_attributes(mode = "0755"),
    prefix = "usr/bin",
    renames = {"//bazel/toolchains:hello_world_hi_for_image": "hello_world_hi"},
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
    maintainer = "Eclipse S-CORE contributors",
    package = "score-reference-integration-hello-world-hi",
    version = "1.0.0",
)

pkg_tar(
    name = "crinit_config_tar",
    srcs = [
        "//images/ebclfsa_aarch64/build/config-overlay:etc/crinit/crinit.d/getty-console.crinit",
    ],
    mode = "0755",
    package_dir = "/etc/crinit/crinit.d",
)

pkg_tar(
    name = "scripts_tar",
    srcs = [
        "//images/ebclfsa_aarch64/build/config-overlay:usr/bin/delayed-start.sh",
    ],
    mode = "0755",
    package_dir = "/usr/bin",
)

pkg_deb(
    name = "platform_deb",
    architecture = "arm64",
    data = "//deploy:platform_tar",
    description = "S-CORE platform files for the fast-dev image",
    maintainer = "Eclipse S-CORE contributors",
    package = "score-reference-integration-platform",
    version = "1.0.0",
)

pkg_deb(
    name = "showcases_deb",
    architecture = "arm64",
    data = "//showcases:showcases_pkg_tar",
    description = "S-CORE showcases for the fast-dev image",
    maintainer = "Eclipse S-CORE contributors",
    package = "score-reference-integration-showcases",
    version = "1.0.0",
)

pkg_deb(
    name = "crinit_config_deb",
    architecture = "all",
    data = ":crinit_config_tar",
    description = "Crinit configuration for the fast-dev image",
    maintainer = "Eclipse S-CORE contributors",
    package = "score-reference-integration-crinit-config",
    replaces = ["ebclfsa-fastdev-crinit-getty"],
    version = "1.0.0",
)

pkg_deb(
    name = "scripts_deb",
    architecture = "all",
    data = ":scripts_tar",
    description = "Scripts for the fast-dev image",
    maintainer = "Eclipse S-CORE contributors",
    package = "score-reference-integration-scripts",
    version = "1.0.0",
)

ebclfsa_aarch64_prebuild(
    base_image = "@ebclfsa_qemu_release_archive//file",
    packages = [
        ":crinit_config_deb",
        ":platform_deb",
        ":scripts_deb",
        ":showcases_deb",
        ":hello_world_hi_deb",
    ],
)
