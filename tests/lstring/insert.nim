discard """
  exitcode: 0
"""

import ../../src/lstring

var testString: LimitedString = initLimitedString(capacity = 15, text = "test")
testString.insert("start and ")
assert $testString == "start and test"
testString.insert("2", 2)
assert $testString == "st2art and test"
try:
  testString.insert("very long text outside of max allowed lenght")
except CapacityError:
  assert $testString == "st2art and test"
