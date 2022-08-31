discard """
  exitcode: 0
"""

import std/tables
import ../../src/[aliases, nish, resultcode]
import utils/helpers

var (db, helpContent, myaliases) = initTest()
assert setTestAliases(db) == QuitSuccess
myaliases = initAliases(helpContent, db)
assert myaliases.len() == 1
assert helpContent.len() == 6
quitShell(ResultCode(QuitSuccess), db)
