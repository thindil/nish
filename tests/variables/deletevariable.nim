discard """
  exitcode: 0
"""

import ../../src/[lstring, nish, variables, resultcode]
import utils/helpers

var (db, _, historyIndex) = initTest()
assert setTestVariables(db) == QuitSuccess
assert deleteVariable(initLimitedString(capacity = 10, text = "delete 123"),
    historyIndex, db) == QuitFailure
assert deleteVariable(initLimitedString(capacity = 10, text = "delete sdf"),
    historyIndex, db) == QuitFailure
assert deleteVariable(initLimitedString(capacity = 8, text = "delete 2"),
    historyIndex, db) == QuitSuccess
assert deleteVariable(initLimitedString(capacity = 8, text = "delete 2"),
    historyIndex, db) == QuitFailure
quitShell(ResultCode(QuitSuccess), db)
