discard """
  exitcode: 0
"""

import ../../src/[nish, variables]
import utils/helpers

var (db, _, historyIndex) = initTest()
historyIndex = helpVariables(db)
quitShell(QuitSuccess, db)
