discard """
  exitcode: 0
"""

import ../../src/[lstring, nish, options, resultcode]
import utils/helpers

let db = initTest()
assert setOptions(initLimitedString(capacity = 22,
    text = "set historyLength 1000"), db) == QuitSuccess
assert getOption(initLimitedString(capacity = 13, text = "historyLength"),
    db) == "1000"
quitShell(ResultCode(QuitSuccess), db)
