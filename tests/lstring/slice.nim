discard """
  exitcode: 0
"""

import ../../src/lstring

let testString: LimitedString = initLimitedString(capacity = 14, text = "test")
assert $testString[1..2] == "es"
