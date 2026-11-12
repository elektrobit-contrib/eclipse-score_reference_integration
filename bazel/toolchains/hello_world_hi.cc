// Copyright (c) 2026 Contributors to the Eclipse Foundation
// SPDX-License-Identifier: Apache-2.0

#include <cstdio>
#include <vector>

#ifndef _LIBCPP_VERSION
#error "This target must be compiled with the EBcLfSA libc++."
#endif

int main() {
  const std::vector<int> values{1, 2, 3};
  if (values.size() != 3 || values.back() != 3) {
    return 1;
  }
  return std::puts("Hello, high-integrity world!") < 0 ? 1 : 0;
}
