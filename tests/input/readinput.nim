discard """
  exitcode: 0
"""

import ../../src/[input, lstring]

assert readInput() == initLimitedString(capacity = 4, text = "exit")
