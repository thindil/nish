discard """
  exitcode: 0
"""

import ../../src/[help, lstring, nish, resultcode]
import utils/helpers

var db = initTest()
assert showHelp(initLimitedString(capacity = 12, text = "alias"), db) == QuitSuccess
assert showHelp(initLimitedString(capacity = 9, text = "srewfdsfs"), db) == QuitFailure
quitShell(ResultCode(QuitSuccess), db)
