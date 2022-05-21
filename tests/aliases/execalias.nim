discard """
  exitcode: 0
"""

import std/os
import ../../src/[aliases, constants, lstring, nish]
import utils/helpers

var (db, _, _, myaliases) = initTest()
assert setTestAliases(db) == QuitSuccess
myaliases.setAliases(getCurrentDir(), db)
assert execAlias(initLimitedString(capacity = 1), "tests", myaliases, db) == QuitSuccess
assert execAlias(initLimitedString(capacity = 1), "tests2", myaliases, db) == QuitFailure
quitShell(ResultCode(QuitSuccess), db)
