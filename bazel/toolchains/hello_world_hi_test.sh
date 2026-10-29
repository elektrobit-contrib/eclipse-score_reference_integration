#!/bin/bash
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

set -euo pipefail

binary=$1
package=$2

[[ -f "$binary" && -x "$binary" ]]

# The SDK uses the final EI_PAD byte as its supervision marker (ASCII 'S').
header=$(od -An -tx1 -N16 "$binary" | tr -d ' \n')
if [[ "$header" != 7f454c46020101000000000000000053 ]]; then
    echo "Error: expected an ELF64 little-endian executable with the HI supervision marker, got $header" >&2
    exit 1
fi
machine=$(od -An -tx1 -j18 -N2 "$binary" | tr -d ' \n')
if [[ "$machine" != b700 ]]; then
    echo "Error: expected an AArch64 executable, got ELF machine $machine" >&2
    exit 1
fi

tar -xf "$package" -C "$TEST_TMPDIR"
installed="$TEST_TMPDIR/usr/bin/hello_world_hi"
[[ -f "$installed" && -x "$installed" && ! -L "$installed" ]]
cmp "$binary" "$installed"
