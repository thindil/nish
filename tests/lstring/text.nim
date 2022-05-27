discard """
  exitcode: 0
"""

import ../../src/lstring

var testString: LimitedString = initLimitedString(capacity = 10)
testString.text = "new text"
assert testString == "new text"
try:
  testString.text = "very long text which should not go"
except CapacityError:
  discard
assert testString == "new text"
