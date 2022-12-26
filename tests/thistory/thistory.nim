discard """
  exitcode: 0
  outputsub: commands from the shell
"""

import std/[db_sqlite, tables]
import ../../src/[commandslist, directorypath, history, lstring, nish, resultcode]

block:
  let db = startDb("test8.db".DirectoryPath)
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

  assert findInHistory(db, initLimitedString(capacity = 7, text = "find te")) ==
      QuitSuccess, "Failed to find a term in the history."
  assert findInHistory(db, initLimitedString(capacity = 8, text = "find asd")) ==
      QuitFailure, "Failed to not find a term in the history."

  assert clearHistory(db) == 0, "Failed to clear the history"
  assert historyLength(db) == 0, "Failed to get the histry length"

  quitShell(ResultCode(QuitSuccess), db)
