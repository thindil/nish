discard """
  exitcode: 0
"""

import ../../src/[nish, variables, resultcode]
import utils/helpers

var (db, _, historyIndex) = initTest()
historyIndex = helpVariables(db)
quitShell(ResultCode(QuitSuccess), db)
