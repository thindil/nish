discard """
  exitcode: 0
"""

import ../../src/[constants, nish]
import utils/helpers

let (db, amount) = initTest()
assert amount > -1
quitShell(ResultCode(QuitSuccess), db)
