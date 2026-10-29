# Copyright (c) 2026 Contributors to the Eclipse Foundation
# SPDX-License-Identifier: Apache-2.0

SUMMARY = "Bazel-built EBcLfSA high-integrity hello world"
LICENSE = "Apache-2.0"

inherit dpkg-prebuilt

SRC_URI = "file://score-hello-world-hi_1.0_arm64.deb"
COMPATIBLE_MACHINE = "ebcl-qemuarm64"
