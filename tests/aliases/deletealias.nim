discard """
  exitcode: 0
"""

import std/[db_sqlite, strutils]
import ../../src/[aliases, lstring, nish, resultcode]
import utils/helpers

var (db, _, myaliases) = initTest()
assert setTestAliases(db) == QuitSuccess
assert deleteAlias(initLimitedString(capacity = 8, text = "delete 2"), myaliases, db) == QuitSuccess
assert parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 1
assert deleteAlias(initLimitedString(capacity = 9, text = "delete 22"), myaliases, db) == QuitFailure
if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
    "tests2", "/", 0, "ls -a", "Test alias 2.") == -1:
  quit("Can't add test2 alias.", QuitFailure)
assert parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 2
quitShell(ResultCode(QuitSuccess), db)
