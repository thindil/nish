discard """
  exitcode: 0
"""

import ../../src/lstring

let testString: LimitedString = initLimitedString(capacity = 14, text = "test")
assert testString.len() == 4
assert testString.capacity == 14
