discard """
  exitcode: 0
"""

import std/os
import ../../src/[constants, lstring, nish, variables]

let db = startDb("test.db")
assert db != nil
assert setCommand(initLimitedString(capacity = 13, text = "test=test_val"),
    db) == QuitSuccess
assert unsetCommand(initLimitedString(capacity = 4, text = "test"), db) == QuitSuccess
assert getEnv("test") == ""
assert unsetCommand(initLimitedString(capacity = 4, text = "test"), db) == QuitSuccess
quitShell(ResultCode(QuitSuccess), db)
