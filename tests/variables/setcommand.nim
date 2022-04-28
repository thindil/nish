discard """
  exitcode: 0
"""

import std/os
import ../../src/[nish, variables]

let db = startDb("test.db")
assert setCommand("test=test_val", db) == QuitSuccess
assert getEnv("test") == "test_val"
quitShell(QuitSuccess, db)
