discard """
  exitcode: 0
"""

import ../../src/lstring

let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
assert $testString == "test"
try:
  let testString2: LimitedString = initLimitedString(capacity = 4, text = "too long text")
  assert $testString2 == "too long text"
except CapacityError:
  quit 0

