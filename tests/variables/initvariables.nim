discard """
  exitcode: 0
"""

import ../../src/[constants, nish, variables]
import utils/helpers

var (db, helpContent, _) = initTest()
initVariables(helpContent, db)
quitShell(ResultCode(QuitSuccess), db)
