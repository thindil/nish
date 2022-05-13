discard """
  exitcode: 0
"""

import ../../src/[nish, options]
import utils/helpers

let db = initTest()
assert resetOptions("reset historyLength", db) == QuitSuccess
assert getOption("historyLength", db) == "500"
quitShell(QuitSuccess, db)
