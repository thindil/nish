discard """
  exitcode: 0
"""

import ../../src/[help, lstring, nish, resultcode]
import utils/helpers

var (db, helpContent) = initTest()
updateHelp(helpContent, db)
assert showHelp(initLimitedString(capacity = 12, text = "history list"),
    helpContent) == QuitSuccess
assert showHelp(initLimitedString(capacity = 9, text = "srewfdsfs"),
    helpContent) == QuitFailure
quitShell(ResultCode(QuitSuccess), db)
