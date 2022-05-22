discard """
  exitcode: 0
"""

import ../../src/[constants, help, lstring, nish]
import utils/helpers

var (db, helpContent) = initTest()
updateHelp(helpContent, db)
assert showHelp(initLimitedString(capacity = 12, text = "history show"), helpContent, db) == QuitSuccess
assert showHelp(initLimitedString(capacity = 9, text = "srewfdsfs"), helpContent, db) == QuitFailure
quitShell(ResultCode(QuitSuccess), db)
