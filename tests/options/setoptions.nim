discard """
  exitcode: 0
"""

import ../../src/[nish, options]
import utils/helpers

let db = initTest()
assert setOptions("set historyLength 1000", db) == QuitSuccess
assert getOption("historyLength", db) == "1000"
quitShell(QuitSuccess, db)
