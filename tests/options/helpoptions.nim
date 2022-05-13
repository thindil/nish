discard """
  exitcode: 0
"""

import ../../src/[nish, options]
import utils/helpers

let db = initTest()
helpOptions(db)
quitShell(QuitSuccess, db)
