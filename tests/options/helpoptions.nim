discard """
  exitcode: 0
"""

import ../../src/[nish, options, resultcode]
import utils/helpers

let db = initTest()
helpOptions(db)
quitShell(ResultCode(QuitSuccess), db)
