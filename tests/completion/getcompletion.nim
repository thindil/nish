discard """
  exitcode: 0
"""

import ../../src/completion

assert getCompletion("C") == "CHANGELOG.md"
