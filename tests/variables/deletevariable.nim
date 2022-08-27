discard """
  exitcode: 0
"""

import ../../src/[lstring, nish, variables, resultcode]
import utils/helpers

var (db, _, _) = initTest()
assert setTestVariables(db) == QuitSuccess
assert deleteVariable(initLimitedString(capacity = 10, text = "delete 123"),
    db) == QuitFailure
assert deleteVariable(initLimitedString(capacity = 10, text = "delete sdf"),
    db) == QuitFailure
assert deleteVariable(initLimitedString(capacity = 8, text = "delete 2"), db) == QuitSuccess
assert deleteVariable(initLimitedString(capacity = 8, text = "delete 2"), db) == QuitFailure
quitShell(ResultCode(QuitSuccess), db)
