discard """
  exitcode: 0
"""

import ../../src/[lstring, nish, options, resultcode]
import utils/helpers

let db  = initTest()
assert getOption(initLimitedString(capacity = 13, text = "historyLength"), db).len() > 0
assert getOption(initLimitedString(capacity = 10, text = "werweewfwe"), db).len() == 0
quitShell(ResultCode(QuitSuccess), db)
