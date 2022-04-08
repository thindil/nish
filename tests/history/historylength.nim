discard """
  exitcode: 0
"""

import std/[db_sqlite, tables]
import ../../src/[constants, history, nish]

let db = startDb("test.db")
assert db != nil
var
    helpContent = initTable[string, HelpEntry]()
    amount = initHistory(db, helpContent)
if amount == 0:
  if db.tryInsertID(sql"INSERT INTO history (command, amount, lastused) VALUES (?, 1, datetime('now'))", "ls -a") == -1:
    quit("Can't add test command to history.", QuitFailure)
assert historyLength(db) > 0
quitShell(QuitSuccess, db)
