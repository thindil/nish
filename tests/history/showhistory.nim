discard """
  exitcode: 0
"""

import ../../src/[constants, history, nish]
import utils/helpers

let (db, amount) = initTest()
if amount == 0:
  assert setTestHistory(db) == QuitSuccess
assert showHistory(db) >= amount
quitShell(ResultCode(QuitSuccess), db)
