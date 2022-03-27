discard """
  exitcode: 0
"""

import os
import ../../src/nish

let db = startDb("test.db")
assert fileExists("test.db")
quitShell(QuitSuccess, db)
