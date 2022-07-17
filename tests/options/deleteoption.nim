discard """
  exitcode: 0
"""

import ../../src/[lstring, nish, options, resultcode]
import utils/helpers

let
  db = initTest()
  optionName = initLimitedString(capacity = 10, text = "testOption")
setOption(optionName = optionName, value = initLimitedString(capacity = 3, text = "200"), db = db)
assert deleteOption(optionName, db) == QuitSuccess
assert getOption(optionName, db).len() == 0
quitShell(ResultCode(QuitSuccess), db)
