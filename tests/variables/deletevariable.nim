discard """
  exitcode: 0
"""

import ../../src/[nish, variables]
import utils/helpers

var (db, _, historyIndex) = initTest()
assert setTestVariables(db) == QuitSuccess
assert deleteVariable("delete 123", historyIndex, db) == QuitFailure
assert deleteVariable("delete sdf", historyIndex, db) == QuitFailure
assert deleteVariable("delete 2", historyIndex, db) == QuitSuccess
assert deleteVariable("delete 2", historyIndex, db) == QuitFailure
quitShell(QuitSuccess, db)
