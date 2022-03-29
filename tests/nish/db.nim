discard """
  exitcode: 0
"""

import ../../src/nish

let db = startDb("test.db")
assert db != nil
quitShell(QuitSuccess, db)
