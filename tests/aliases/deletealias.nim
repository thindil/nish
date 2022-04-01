discard """
  exitcode: 0
"""

import std/[db_sqlite, strutils, tables]
import ../../src/[aliases, constants, history, nish]

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
    helpContent = initTable[string, HelpEntry]()
    historyIndex = initHistory(db, helpContent)
assert deleteAlias("delete 2", historyIndex, myaliases, db) == QuitSuccess
assert parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 1
assert deleteAlias("delete 22", historyIndex, myaliases, db) == QuitFailure
if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
    "tests2", "/", 0, "ls -a", "Test alias 2.") == -1:
  quit("Can't add test2 alias.", QuitFailure)
assert parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 2
quitShell(QuitSuccess, db)
