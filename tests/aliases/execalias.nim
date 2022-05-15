discard """
  exitcode: 0
"""

import std/[db_sqlite, os, strutils]
import ../../src/[aliases, constants, nish]
import utils/helpers

var (db, _, _, myaliases) = initTest()
if parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 0:
    if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
        "tests", "/", 1, "ls -a", "Test alias.") == -1:
      quit("Can't add test alias.", QuitFailure)
    if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
        "tests2", "/", 0, "ls -a", "Test alias 2.") == -1:
      quit("Can't add test2 alias.", QuitFailure)
myaliases.setAliases(getCurrentDir(), db)
assert execAlias("", "tests", myaliases, db) == QuitSuccess
assert execAlias("", "tests2", myaliases, db) == QuitFailure
quitShell(ResultCode(QuitSuccess), db)
