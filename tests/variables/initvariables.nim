discard """
  exitcode: 0
"""

import ../../src/[nish, variables]
import utils/helpers

var (db, helpContent, _) = initTest()
initVariables(helpContent, db)
quitShell(QuitSuccess, db)
