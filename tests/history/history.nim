discard """
  exitcode: 0
"""

import std/[db_sqlite, tables]
import ../../src/[commandslist, directorypath, history, lstring, nish, resultcode]

let db = startDb("test.db".DirectoryPath)
assert db != nil, "Failed to initialize the database."
var commands = newTable[string, CommandData]()
var amount = initHistory(db, commands)
if amount == 0:
  if db.tryInsertID(sql"INSERT INTO history (command, amount, lastused) VALUES (?, 1, datetime('now'))",
      "alias delete") == -1:
    quit QuitFailure

assert getHistory(1, db) == "alias delete", "Failed to get the history entry."

amount = historyLength(db)
assert updateHistory("test comm", db) == amount + 1, "Failed to update the history."

assert historyLength(db) > 0

assert showHistory(db, initLimitedString(capacity = 4, text = "list")) ==
    QuitSuccess, "Failed to show the history."

assert clearHistory(db) == 0, "Failed to clear the history"
assert historyLength(db) == 0, "Failed to get the histry length"

quitShell(ResultCode(QuitSuccess), db)
