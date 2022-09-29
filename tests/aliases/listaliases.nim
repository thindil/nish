discard """
  outputsub: Test alias.
"""

import std/[db_sqlite, os, strutils]
import ../../src/[aliases, directorypath, lstring, nish, resultcode]
import utils/helpers
import contracts

var (db, myaliases) = initTest()
assert setTestAliases(db) == QuitSuccess
myaliases.setAliases(getCurrentDir().DirectoryPath, db)
assert parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 2
assert listAliases(initLimitedString(capacity = 4, text = "list"), myaliases,
    db) == QuitSuccess
assert listAliases(initLimitedString(capacity = 8, text = "list all"),
    myaliases, db) == QuitSuccess
try:
  assert listAliases(initLimitedString(capacity = 8, text = "werwerew"),
      myaliases, db) == QuitSuccess
except PreConditionDefect:
  discard
quitShell(ResultCode(QuitSuccess), db)
