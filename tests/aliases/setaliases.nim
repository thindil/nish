discard """
  exitcode: 0
"""

import std/[db_sqlite, os, strutils, tables]
import ../../src/[nish, aliases]

let db = startDb("test.db")
if parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 0:
    if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
        "tests", "/", 1, "ls -a", "Test alias.") == -1:
      quit("Can't add test alias.", QuitFailure)
var myaliases = initOrderedTable[string, int]()
myaliases.setAliases(getCurrentDir(), db)
assert myaliases.len() == 1
quitShell(QuitSuccess, db)
