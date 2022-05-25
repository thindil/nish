discard """
  exitcode: 0
"""

import ../../src/[constants, lstring, nish, options]
import utils/helpers

let db = initTest()
setOption(optionName = initLimitedString(capacity = 13, text = "historyLength"),
    value = initLimitedString(capacity = 3, text = "100"), db = db)
assert getOption(initLimitedString(capacity = 13, text = "historyLength"),
    db) == "100"
quitShell(ResultCode(QuitSuccess), db)
