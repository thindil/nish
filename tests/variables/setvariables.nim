discard """
  exitcode: 0
"""

import std/os
import ../../src/[constants, nish, variables, resultcode]
import utils/helpers

let (db, _, _) = initTest()
assert setTestVariables(db) == QuitSuccess
setVariables("/home".DirectoryPath, db)
assert getEnv("TESTS") == "test_variable"
assert not existsEnv("TESTS2")
quitShell(ResultCode(QuitSuccess), db)
