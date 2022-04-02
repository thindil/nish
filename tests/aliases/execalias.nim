discard """
  exitcode: 0
"""

import std/[db_sqlite, os, strutils, tables]
import ../../src/[aliases, nish]

let db = startDb("test.db")
if parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 0:
    if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
        "tests", "/", 1, "ls -a", "Test alias.") == -1:
      quit("Can't add test alias.", QuitFailure)
    if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
        "tests2", "/", 0, "ls -a", "Test alias 2.") == -1:
      quit("Can't add test2 alias.", QuitFailure)
var
    myaliases = initOrderedTable[string, int]()
myaliases.setAliases(getCurrentDir(), db)
assert execAlias("", "tests", myaliases, db) == QuitSuccess
assert execAlias("", "tests2", myaliases, db) == QuitFailure
quitShell(QuitSuccess, db)
