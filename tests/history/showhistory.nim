discard """
  exitcode: 0
"""

import ../../src/[history, nish, resultcode]
import utils/helpers

let (db, amount) = initTest()
if amount == 0:
  assert setTestHistory(db) == QuitSuccess
assert showHistory(db) == QuitSuccess
quitShell(ResultCode(QuitSuccess), db)
