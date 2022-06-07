discard """
  exitcode: 0
"""

import ../../src/[nish, resultcode]
import utils/helpers

let (db, amount) = initTest()
assert amount > -1
quitShell(ResultCode(QuitSuccess), db)
