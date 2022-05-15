discard """
  exitcode: 0
"""

import ../../src/[constants, commands, nish]
import utils/helpers

var (db, myaliases) = initTest()
assert changeDirectory("..", myaliases, db) == QuitSuccess
assert changeDirectory("/adfwerewtr", myaliases, db) == QuitFailure
quitShell(ResultCode(QuitSuccess), db)
