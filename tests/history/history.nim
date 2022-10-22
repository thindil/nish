discard """
  exitcode: 0
"""

import std/[db_sqlite, tables]
import ../../src/[commandslist, directorypath, history, nish, resultcode]

let db = startDb("test.db".DirectoryPath)
assert db != nil
var commands = newTable[string, CommandData]()
var amount = initHistory(db, commands)
if amount == 0:
  if db.tryInsertID(sql"INSERT INTO history (command, amount, lastused) VALUES (?, 1, datetime('now'))",
      "alias delete") == -1:
    quit QuitFailure

assert getHistory(1, db) == "alias delete"

amount = historyLength(db)
assert updateHistory("test comm", db) == amount + 1

assert historyLength(db) > 0

assert showHistory(db) == QuitSuccess

assert clearHistory(db) == 0
assert historyLength(db) == 0

quitShell(ResultCode(QuitSuccess), db)
