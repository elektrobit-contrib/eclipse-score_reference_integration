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

load("@rules_pkg//pkg:deb.bzl", "pkg_deb")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@rules_shell//shell:sh_test.bzl", "sh_test")

IMAGE_PACKAGES = [
    ":showcases_deb",
    "//bazel/toolchains:hello_world_hi_deb",
    ":config_deb",
]

pkg_deb(
    name = "showcases_deb",
    architecture = "arm64",
    data = "//showcases:showcases_pkg_tar",
    depends = [
        "libc6",
        "libgcc-s1",
        "libstdc++6",
    ],
    description = "Eclipse S-CORE showcases for EB corbos Linux for Safety Applications",
    homepage = "https://github.com/eclipse-score/reference_integration",
    maintainer = "Eclipse S-CORE contributors <score-dev@eclipse.org>",
    package = "score-showcases",
    target_compatible_with = [
        "@platforms//cpu:aarch64",
        "@platforms//os:linux",
    ],
    version = "1.0",
    visibility = ["//visibility:public"],
)

pkg_tar(
    name = "getty_console_tar",
    srcs = ["//images/ebclfsa_aarch64/build/config-overlay:etc/crinit/crinit.d/getty-console.crinit"],
    mode = "0644",
    package_dir = "/etc/crinit/crinit.d",
)

pkg_tar(
    name = "delayed_start_tar",
    srcs = ["//images/ebclfsa_aarch64/build/config-overlay:usr/bin/delayed-start.sh"],
    mode = "0755",
    package_dir = "/usr/bin",
)

pkg_tar(
    name = "config_tar",
    deps = [
        ":delayed_start_tar",
        ":getty_console_tar",
    ],
)

pkg_deb(
    name = "config_deb",
    architecture = "all",
    conffiles = ["/etc/crinit/crinit.d/getty-console.crinit"],
    data = ":config_tar",
    depends = ["ebclfsa-fastdev-crinit-getty"],
    description = "S-CORE showcase console configuration and delayed startup",
    maintainer = "Eclipse S-CORE contributors <score-dev@eclipse.org>",
    package = "config-deb",
    replaces = ["ebclfsa-fastdev-crinit-getty"],
    version = "1.0",
    visibility = ["//visibility:public"],
)

genrule(
    name = "image",
    srcs = [
        "kas.yml",
        "@eb_corbos_toolkit//:BUILD.bazel",
        "@eb_corbos_toolkit//:sources",
    ] + IMAGE_PACKAGES + glob(["meta-score/**"]),
    outs = [
        "fastdev-trixie-ebclfsa-ebcl-qemuarm64-vmlinux",
        "fastdev-trixie-ebclfsa-ebcl-qemuarm64.wic",
    ],
    cmd = "bash $(location build_image.sh) " +
          "$$(dirname $(location @eb_corbos_toolkit//:BUILD.bazel)) " +
          "$(location kas.yml) " +
          "$(RULEDIR) " +
          " ".join(["\"$(location %s)\"" % package for package in IMAGE_PACKAGES]),
    local = True,
    tags = ["manual"],
    tools = ["build_image.sh"],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "run",
    srcs = ["//runners/qemu_aarch64/scripts:run_qemu.sh"],
    args = [
        "$(location :fastdev-trixie-ebclfsa-ebcl-qemuarm64-vmlinux)",
        "$(location :fastdev-trixie-ebclfsa-ebcl-qemuarm64.wic)",
        "-append",
        "'root=/dev/vda1 sdk_enable lisa_syscall_whitelist=2026 rw sharedmem.enable_sharedmem=0 init=/usr/bin/ebclfsa-cflinit'",
        "-snapshot",
    ],
    data = [
        ":fastdev-trixie-ebclfsa-ebcl-qemuarm64.wic",
        ":fastdev-trixie-ebclfsa-ebcl-qemuarm64-vmlinux",
    ],
    tags = ["manual"],
    use_bash_launcher = True,
    visibility = ["//visibility:public"],
)

sh_test(
    name = "build_image_test",
    size = "small",
    srcs = ["build_image_test.sh"],
    args = [
        "$(location :config_deb)",
    ],
    data = [
        "build_image.sh",
        "kas.yml",
        ":config_deb",
        "//images/ebclfsa_aarch64/build/config-overlay:etc/crinit/crinit.d/getty-console.crinit",
        "//images/ebclfsa_aarch64/build/config-overlay:usr/bin/delayed-start.sh",
    ] + glob(["meta-score/**"]),
)
