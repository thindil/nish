discard """
  exitcode: 0
"""

import ../../src/[nish, options]
import utils/helpers

let db = initTest()
showOptions(db)
quitShell(QuitSuccess, db)
