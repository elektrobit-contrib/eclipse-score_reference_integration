#!/bin/bash
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

set -uoex pipefail

LISA_ELF_ENABLER=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --lisa-elf-enabler)
            if [[ $# -lt 2 ]]; then
                echo "Error: --lisa-elf-enabler requires a path" >&2
                exit 1
            fi
            LISA_ELF_ENABLER="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

if [[ $# -lt 4 ]]; then
    echo "Error: Expected at least 4 arguments (working directoy, image source location, image target location, and one or more tar files to deploy relative to the root of the image)" >&2
    exit 1
fi

# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
    echo "Error: sshpass is not installed. Please install it to proceed." >&2
    exit 1
fi

WORKING_DIR="$1"
IMAGE_SOURCE="$2"
IMAGE_TARGET="$3"
shift 3
DEPLOY_SRCS=("$@")
SSH_OPTIONS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)

if [[ -z "$LISA_ELF_ENABLER" || ! -x "$LISA_ELF_ENABLER" ]]; then
    echo "Error: lisa-elf-enabler is not available or not executable: $LISA_ELF_ENABLER" >&2
    exit 1
fi

# Validate that the source directory exists
if [[ ! -d "$IMAGE_SOURCE" ]]; then
    echo "Error: Image source location is not a directory: $IMAGE_SOURCE" >&2
    exit 1
fi

# Check for .wic file
if ! find "$IMAGE_SOURCE" -maxdepth 1 \( -name "*.wic" -type f -o -name "*.wic" -type l \) | grep -q .; then
    echo "Error: No .wic file found in $IMAGE_SOURCE" >&2
    exit 1
fi

# Check for vmlinux file
if ! find "$IMAGE_SOURCE" -maxdepth 1 \( -name "*vmlinux" -type f -o -name "*vmlinux" -type l \) | grep -q .; then
    echo "Error: No vmlinux file found in $IMAGE_SOURCE" >&2
    exit 1
fi

# Validate that the target directory exists
if [[ ! -d "$IMAGE_TARGET" ]]; then
    echo "Error: Image target location is not a directory: $IMAGE_TARGET" >&2
    exit 1
fi

# Validate that each deploy source exists
for src in "${DEPLOY_SRCS[@]}"; do
    if [[ ! -f "$src" ]]; then
        echo "Error: Deploy source file does not exist: $src" >&2
        exit 1
    fi
    # Check if the file is a tar file
    if [[ ! "$src" =~ \.tar(\.(gz|bz2|xz))?$ ]]; then
        echo "Error: Deploy source is not a tar file: $src" >&2
        exit 1
    fi
done

# Prepare each archive locally, marking ELF applications before deployment.
PREPROCESS_DIR=$(mktemp -d "$WORKING_DIR/deploy.XXXXXX")
PREPARED_SRCS=()
for index in "${!DEPLOY_SRCS[@]}"; do
    src="${DEPLOY_SRCS[$index]}"
    archive_dir="$PREPROCESS_DIR/extract-$index"
    mkdir -p "$archive_dir"
    tar -xf "$src" -C "$archive_dir"

    while IFS= read -r -d '' application; do
        [[ "$application" == */bin/* ]] || continue
        [[ "$application" == *.so && "$application" != *.so.* ]] && continue
        [[ "$application" == *.so.* ]] && continue

        magic=""
        IFS= read -r -N 4 magic < "$application" || true
        [[ "$magic" == $'\177ELF' ]] && "$LISA_ELF_ENABLER" "$application"
    done < <(find "$archive_dir" -type f -print0)

    prepared_src="$PREPROCESS_DIR/$index-$(basename "$src")"
    tar -caf "$prepared_src" -C "$archive_dir" .
    PREPARED_SRCS+=("$prepared_src")
done

# Clear target directory and copy source directory content to target directory
mkdir -p "$IMAGE_TARGET"
rm -f "${IMAGE_TARGET:?}/"*
cp -L "$IMAGE_SOURCE"/* "$IMAGE_TARGET"/

IMAGE=$(find "$IMAGE_TARGET" -maxdepth 1 \( -name "*.wic" -type f -o -name "*.wic" -type l \) -print -quit)
KERNEL=$(find "$IMAGE_TARGET" -maxdepth 1 \( -name "*vmlinux" -type f -o -name "*vmlinux" -type l \) -print -quit)

# the image file needs to be writable for qemu to run, so we change the permissions here
chmod +w "$IMAGE"

qemu-system-aarch64 -m 2048 -cpu cortex-a53 -machine virt \
    -kernel "$KERNEL" \
    -machine "virt,virtualization=true,gic-version=3" \
    -smp 8 \
    -device virtio-blk-device,drive=vd0 -drive if=none,format=raw,file="${IMAGE}",id=vd0 \
    -append "root=/dev/vda1 sdk_enable lisa_syscall_whitelist=2026 rw sharedmem.enable_sharedmem=0 init=/usr/bin/ebclfsa-cflinit" \
    -netdev user,id=net0,net=192.168.7.0/24,dhcpstart=192.168.7.2,dns=192.168.7.3,host=192.168.7.5,hostfwd=tcp::2222-:22,hostfwd=tcp::3333-:3333 -device virtio-net-device,netdev=net0 \
    -pidfile "$WORKING_DIR/qemu.pid" \
    -nographic \
     > "$WORKING_DIR/qemu_deployment.log" \
    &

# Wait for QEMU to be accessible via SSH
for i in {1..60}; do
    if sshpass -p linux ssh "${SSH_OPTIONS[@]}" -o ConnectTimeout=1 -p 2222 root@localhost true 2>/dev/null; then
        echo "QEMU is accessible"
        break
    fi
    echo "Waiting for QEMU to be ready... ($i/60)"
    sleep 1
done

# deploy files to QEMU via scp
for src in "${PREPARED_SRCS[@]}"; do
    sshpass -p linux scp -rp "${SSH_OPTIONS[@]}" -P 2222 "$src" root@localhost:/
    sshpass -p linux ssh "${SSH_OPTIONS[@]}" -p 2222 root@localhost "tar -xf /$(basename "$src") -C /"
    sshpass -p linux ssh "${SSH_OPTIONS[@]}" -p 2222 root@localhost "rm -f /$(basename "$src")"
done

# Shutdown QEMU via SSH
sshpass -p linux ssh "${SSH_OPTIONS[@]}" -p 2222 root@localhost sync
sshpass -p linux ssh "${SSH_OPTIONS[@]}" -p 2222 root@localhost crinit-ctl poweroff || true

# Wait for QEMU process to finish
if [[ -f "$WORKING_DIR/qemu.pid" ]]; then
    wait "$(cat "$WORKING_DIR/qemu.pid")" 2>/dev/null || true
    rm -f "$WORKING_DIR/qemu.pid"
fi
