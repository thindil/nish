discard """
  exitcode: 0
"""

import ../../src/[nish, options]
import utils/helpers

let db  = initTest()
assert getOption("historyLength", db).len() > 0
assert getOption("werweewfwe", db).len() == 0
quitShell(QuitSuccess, db)
