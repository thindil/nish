discard """
  outputsub: Test variable.
"""

import ../../src/[constants, nish, variables]
import utils/helpers

var (db, _, historyIndex) = initTest()
assert setTestVariables(db) == QuitSuccess
listVariables("list", historyIndex, db)
listVariables("list all", historyIndex, db)
listVariables("werwerew", historyIndex, db)
quitShell(ResultCode(QuitSuccess), db)
