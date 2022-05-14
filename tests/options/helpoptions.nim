discard """
  exitcode: 0
"""

import ../../src/[constants, nish, options]
import utils/helpers

let db = initTest()
helpOptions(db)
quitShell(ResultCode(QuitSuccess), db)
