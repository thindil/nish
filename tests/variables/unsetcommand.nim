discard """
  exitcode: 0
"""

import std/os
import ../../src/[nish, variables]

let db = startDb("test.db")
assert setCommand("test=test_val", db) == QuitSuccess
assert unsetCommand("test", db) == QuitSuccess
assert getEnv("test") == ""
assert unsetCommand("test", db) == QuitSuccess
quitShell(QuitSuccess, db)
