discard """
  exitcode: 0
"""

import std/os
import ../../src/[constants, nish, variables]

let db = startDb("test.db")
assert db != nil
assert setCommand("test=test_val", db) == QuitSuccess
assert getEnv("test") == "test_val"
quitShell(ResultCode(QuitSuccess), db)
