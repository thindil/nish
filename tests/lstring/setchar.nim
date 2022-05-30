discard """
  exitcode: 0
"""

import ../../src/lstring

var testString: LimitedString = initLimitedString(capacity = 14, text = "test")
testString[3] = 'a'
assert $testString == "tesa"
