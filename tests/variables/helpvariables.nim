discard """
  exitcode: 0
"""

import ../../src/[constants, nish, variables]
import utils/helpers

var (db, _, historyIndex) = initTest()
historyIndex = helpVariables(db)
quitShell(ResultCode(QuitSuccess), db)
