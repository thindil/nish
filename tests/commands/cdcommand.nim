discard """
  exitcode: 0
"""

import ../../src/[constants, commands, nish]
import utils/helpers

var (db, myaliases) = initTest()
assert cdCommand("/", myaliases, db) == QuitSuccess
assert cdCommand("/adfwerewtr", myaliases, db) == QuitFailure
quitShell(ResultCode(QuitSuccess), db)
