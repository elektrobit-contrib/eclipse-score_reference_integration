# EB corbos Linux for Safety Applications: image from scratch

```bash
bazel run --config=eb-aarch64 //images/ebclfsa_aarch64_from_scratch:run
```

This cross-compiles the showcases with the EB aarch64 toolchains, packages
[`//showcases:showcases_pkg_tar`](../../showcases/BUILD) as the `score-showcases`
arm64 Debian package, and builds a new `fastdev` disk image with KAS/Isar.
It also builds [`hello_world_hi.cc`](../../bazel/toolchains/hello_world_hi.cc)
with `//bazel/toolchains:score_ebclfsa_toolchain_hi` and installs the separate
`score-hello-world-hi` arm64 Debian package. A per-target transition selects
the HI toolchain for this executable while the showcases retain the regular
EB toolchains selected by `--config=eb-aarch64`. The HI executable statically
links the SDK's musl and libc++ runtimes; it needs no glibc or libstdc++ package
dependencies.
The image is assembled from Debian packages using a Git checkout of the
[EB corbos Toolkit v2.0.0-beta3 tag](https://github.com/Elektrobit/eb_corbos_toolkit/tree/v2.0.0-beta3),
pinned to its commit in `MODULE.bazel`. Only the KAS configuration, bundled Isar
layers and development-container setup are copied into the build workspace.
The large delivery archive, including its prebuilt container and disk images,
is not downloaded. The build container is pulled separately from GHCR.
It does **not** boot or modify the toolkit's prebuilt disk image.
The toolkit still supplies precompiled system packages, including the kernel;
this is an image build from packages, not a source rebuild of the entire OS.

## Requirements

- An x86_64 Linux host with Docker and permission to run privileged containers.
  The Docker daemon must see the Bazel output directory at the same absolute
  path as the build process (not a remote Docker daemon).
- Network access to GitHub, GHCR, and the package repositories referenced by the
  toolkit; substantial free disk space for the Isar build.
- `qemu-system-aarch64` and passwordless `sudo`, as required by the existing
  [QEMU runner](../../runners/qemu_aarch64/scripts/run_qemu.sh).

The local image-building action runs the toolkit's digest-pinned v18 development
container. It registers its aarch64 binfmt interpreter if none is registered;
this requires privileged access and affects the host kernel's binfmt registry.
Existing aarch64 registrations are left untouched. KAS/Isar needs privileges
for chroots and mounts, so this action cannot run in a Bazel sandbox or on a
remote executor.

## Outputs and boot

To build without starting QEMU:

```bash
bazel build --config=eb-aarch64 //images/ebclfsa_aarch64_from_scratch:image
```

The kernel and `.wic` disk image are written to
`bazel-bin/images/ebclfsa_aarch64_from_scratch/`. The temporary KAS workspace
is removed after the build. The showcases are installed at `/showcases`.
The existing console configuration starts the showcase CLI automatically.
The HI example is installed at `/usr/bin/hello_world_hi`; run it from the guest
shell to print `Hello, high-integrity world!`.
QEMU uses a temporary disk snapshot so running it does not modify Bazel's
image output. Exit QEMU with `Ctrl-a x`.

The Debian package can also be built separately:

```bash
bazel build --config=eb-aarch64 //showcases:showcases_deb
bazel build --config=eb-aarch64 //bazel/toolchains:hello_world_hi_deb
```

The HI package's transition also works under `--config=linux-x86_64`; its
payload is always the aarch64 HI executable, independently of the caller's
target platform.

The original [prebuilt-image integration](../ebclfsa_aarch64/README.md) remains
available unchanged.

## Tests

The staging test checks package and console configuration placement, excludes
prebuilt images, and verifies cleanup and failure propagation without Docker:

```bash
bazel test --config=eb-aarch64 //images/ebclfsa_aarch64_from_scratch:build_image_test
```
