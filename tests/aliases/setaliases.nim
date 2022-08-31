discard """
  exitcode: 0
"""

import std/[db_sqlite, os, strutils, tables]
import ../../src/[aliases, directorypath, nish, resultcode]
import utils/helpers

var (db, _, myaliases) = initTest()
assert setTestAliases(db) == QuitSuccess
myaliases.setAliases(getCurrentDir().DirectoryPath, db)
assert parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 2
assert myaliases.len() == 1
quitShell(ResultCode(QuitSuccess), db)
