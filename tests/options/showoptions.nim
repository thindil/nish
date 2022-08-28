discard """
  exitcode: 0
"""

import ../../src/[nish, options, resultcode]
import utils/helpers

let db = initTest()
assert showOptions(db) == QuitSuccess
quitShell(ResultCode(QuitSuccess), db)
