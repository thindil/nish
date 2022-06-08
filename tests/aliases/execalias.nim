discard """
  exitcode: 0
"""

import std/os
import ../../src/[aliases, directorypath, lstring, nish, resultcode]
import utils/helpers

var (db, _, _, myaliases) = initTest()
assert setTestAliases(db) == QuitSuccess
myaliases.setAliases(getCurrentDir().DirectoryPath, db)
assert execAlias(emptyLimitedString(), "tests", myaliases, db) == QuitSuccess
assert execAlias(emptyLimitedString(), "tests2", myaliases, db) == QuitFailure
quitShell(ResultCode(QuitSuccess), db)
