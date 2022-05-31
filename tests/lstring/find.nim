discard """
  exitcode: 0
"""

import ../../src/lstring

let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
assert testString.find('e') == 1
assert testString.find('a') == -1
