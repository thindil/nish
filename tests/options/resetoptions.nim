discard """
  exitcode: 0
"""

import ../../src/[lstring, nish, options, resultcode]
import utils/helpers

let db = initTest()
assert resetOptions(initLimitedString(capacity = 19,
    text = "reset historyLength"), db) == QuitSuccess
assert getOption(initLimitedString(capacity = 13, text = "historyLength"),
    db) == "500"
quitShell(ResultCode(QuitSuccess), db)
