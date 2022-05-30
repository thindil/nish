discard """
  exitcode: 0
"""

import ../../src/lstring

var testString: LimitedString = initLimitedString(capacity = 4, text = "")
assert $testString == ""
try:
  testString.setString(text = "test")
  assert $testString == "test"
except CapacityError:
  discard
try:
  testString.setString(text = "testdfwerwerwerwewr")
except CapacityError:
  assert $testString == "test"
