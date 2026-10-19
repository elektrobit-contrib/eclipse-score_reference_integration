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
import pytest

from scripts.summarize_disallowed_syscalls import summarize


def test_counts_reset_at_every_example() -> None:
    lines = [
        "syscall __NR_futex (98) is not allowed\n",
        "\u25b6 Running example: cli\n",
        "[1.0] SDK:handler: syscall __NR_futex (98) is not allowed\n",
        "[1.1] SDK:handler: syscall __NR_futex (98) is not allowed\n",
        "syscall __NR_statx (291) is not allowed\n",
        "syscall __NR_read (63) is allowed\n",
        "unrelated output\n",
        "\u25b6 Running example: logging\r\n",
        "syscall __NR_futex (98) is not allowed\n",
        "\u25b6 Running example: cli\n",
        "syscall __NR_futex (98) is not allowed",
    ]

    assert summarize(iter(lines)) == (
        "||Application||syscall||count||\n"
        "|cli|__NR_futex (98)|2|\n"
        "|cli|__NR_statx (291)|1|\n"
        "|logging|__NR_futex (98)|1|\n"
        "|cli|__NR_futex (98)|1|\n"
    )


@pytest.mark.parametrize(
    "lines",
    [
        [],
        ["syscall __NR_futex (98) is not allowed\n"],
        ["\u25b6 Running example: empty\n", "ordinary output\n"],
    ],
)
def test_no_disallowed_syscalls(lines: list[str]) -> None:
    assert summarize(lines) == "||Application||syscall||count||\n"


def test_application_whitespace_and_table_delimiter() -> None:
    assert (
        summarize(
            [
                "  \u25b6 Running example: some|example  \r\n",
                "syscall __NR_futex (98) is not allowed\n",
            ]
        )
        == "||Application||syscall||count||\n|some\\|example|__NR_futex (98)|1|\n"
    )


def test_syscall_numbers_are_preserved_and_counted_separately() -> None:
    assert summarize(
        [
            "\u25b6 Running example: cli\n",
            "syscall __NR_ioctl (29) is not allowed\n",
            "syscall __NR_ioctl (29) is not allowed\n",
            "syscall __NR_ioctl (16) is not allowed\n",
        ]
    ) == ("||Application||syscall||count||\n|cli|__NR_ioctl (16)|1|\n|cli|__NR_ioctl (29)|2|\n")


def test_null_syscalls_are_counted_per_number_and_example() -> None:
    assert summarize(
        [
            "\u25b6 Running example: cli\n",
            "[  162.715600] SDK:handler_do_el0_svc_pre: syscall (null) (435) is not allowed\n",
            "syscall (null) (435) is not allowed\n",
            "syscall (null) (436) is not allowed\n",
            "syscall (null) (437) is allowed\n",
            "\u25b6 Running example: logging\n",
            "syscall (null) (435) is not allowed\n",
        ]
    ) == ("||Application||syscall||count||\n|cli|(null) (435)|2|\n|cli|(null) (436)|1|\n|logging|(null) (435)|1|\n")
