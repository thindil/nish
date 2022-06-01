discard """
  exitcode: 0
"""

import ../../src/[input, lstring]

let testString: LimitedString = emptyLimitedString(maxInputLength)
assert testString.capacity == maxInputLength
assert testString == ""
