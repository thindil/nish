discard """
  exitcode: 0
"""

import std/[db_sqlite, strutils, tables]
import ../../src/[constants, history, nish, variables]

let db = startDb("test.db")
if parseInt(db.getValue(sql"SELECT COUNT(*) FROM variables")) == 0:
    if db.tryInsertID(sql"INSERT INTO variables (name, path, recursive, value, description) VALUES (?, ?, ?, ?, ?)",
        "TESTS", "/", 1, "test_variable", "Test variable.") == -1:
      quit("Can't add test variable.", QuitFailure)
    if db.tryInsertID(sql"INSERT INTO variables (name, path, recursive, value, description) VALUES (?, ?, ?, ?, ?)",
        "TESTS2", "/", 0, "test_variable2", "Test variable 2.") == -1:
      quit("Can't add test2 alias.", QuitFailure)
var
    helpContent = initTable[string, HelpEntry]()
    historyIndex = initHistory(db, helpContent)
assert deleteVariable("delete 123", historyIndex, db) == QuitFailure
assert deleteVariable("delete sdf", historyIndex, db) == QuitFailure
assert deleteVariable("delete 2", historyIndex, db) == QuitSuccess
assert deleteVariable("delete 2", historyIndex, db) == QuitFailure
quitShell(QuitSuccess, db)
