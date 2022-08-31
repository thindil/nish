discard """
  exitcode: 0
"""

import ../../src/[nish, variables, resultcode]
import utils/helpers

var (db, helpContent) = initTest()
initVariables(helpContent, db)
quitShell(ResultCode(QuitSuccess), db)
