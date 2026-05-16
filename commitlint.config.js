#
# Copyright (c) 2026 WolfTech-Innovations
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#
module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "body-max-line-length": [0, "always"],
  },
};
