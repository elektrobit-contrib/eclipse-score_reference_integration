#!/usr/bin/env python3
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
"""Count disallowed syscalls per example and print a Jira wiki table."""

import argparse
import re
from collections import Counter
from collections.abc import Iterable
from pathlib import Path

EXAMPLE_PATTERN = re.compile(r"^\s*\u25b6 Running example:\s*(\S.*?)\s*$")
SYSCALL_PATTERN = re.compile(r"\bsyscall\s+((?:\w+|\(null\))\s+\(\d+\))\s+is not allowed\b")


def summarize(lines: Iterable[str]) -> str:
    """Keep each example run separate, including repeated application names."""
    runs: list[tuple[str, Counter[str]]] = []
    counts: Counter[str] | None = None
    for line in lines:
        example = EXAMPLE_PATTERN.match(line)
        if example:
            counts = Counter()
            runs.append((example.group(1), counts))
            continue
        if counts is not None:
            syscall = SYSCALL_PATTERN.search(line)
            if syscall:
                counts[syscall.group(1)] += 1

    rows = ["||Application||syscall||count||"]
    for application, counts in runs:
        application = application.replace("|", r"\|")
        for syscall, count in sorted(counts.items()):
            rows.append(f"|{application}|{syscall}|{count}|")
    return "\n".join(rows) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path, help="UTF-8 log file to summarize")
    args = parser.parse_args()
    try:
        with args.log.open(encoding="utf-8") as log:
            table = summarize(log)
    except (OSError, UnicodeError) as error:
        parser.exit(1, f"{parser.prog}: {error}\n")
    print(table, end="")


if __name__ == "__main__":
    main()
