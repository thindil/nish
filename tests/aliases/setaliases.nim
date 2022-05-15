discard """
  exitcode: 0
"""

import std/[db_sqlite, os, strutils, tables]
import ../../src/[aliases, constants, nish]
import utils/helpers

var (db, _, _, myaliases) = initTest()
assert setTestAliases(db) == QuitSuccess
myaliases.setAliases(getCurrentDir(), db)
assert parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 2
assert myaliases.len() == 1
quitShell(ResultCode(QuitSuccess), db)
