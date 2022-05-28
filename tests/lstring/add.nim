discard """
  exitcode: 0
"""

import ../../src/lstring

var testString: LimitedString = initLimitedString(capacity = 14, text = "test")
testString.add(" and test")
assert $testString == "test and test"
testString.add("2")
assert $testString == "test and test2"
try:
  testString.add("very long text outside of max allowed lenght")
except CapacityError:
  assert $testString == "test and test2"
