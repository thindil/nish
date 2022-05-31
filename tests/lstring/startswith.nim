discard """
  exitcode: 0
"""

import ../../src/lstring

let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
assert testString.startsWith("te")
assert not testString.startsWith("as")
