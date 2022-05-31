discard """
  exitcode: 0
"""

import ../../src/lstring

let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
assert testString.rfind('e') == 1
assert testString.rfind('a') == -1
