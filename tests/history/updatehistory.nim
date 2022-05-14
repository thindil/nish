discard """
  exitcode: 0
"""

import ../../src/[constants, history, nish]
import utils/helpers

let (db, amount) = initTest()
if amount == 0:
  assert setTestHistory(db) == QuitSuccess
assert updateHistory("test comm", db) == amount + 1
quitShell(ResultCode(QuitSuccess), db)
