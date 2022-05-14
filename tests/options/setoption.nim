discard """
  exitcode: 0
"""

import ../../src/[constants, nish, options]
import utils/helpers

let db = initTest()
setOption(optionName = "historyLength", value = "100", db = db)
assert getOption("historyLength", db) == "100"
quitShell(ResultCode(QuitSuccess), db)
