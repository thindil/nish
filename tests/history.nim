import std/tables
import utils/utils
import ../src/[commandslist, db, history, lstring, resultcode]
import unittest2

suite "Unit tests for history module":

  checkpoint "Initializing the tests"
  let db = initDb("test8.db")
  var commands = newTable[string, CommandData]()

  checkpoint "Initializing the shell's history"
  var amount = initHistory(db, commands)
  if amount == 0:
    discard updateHistory("alias delete", db)

  test "Getting the shell's history entry":
    check:
      getHistory(1, db) == "alias delete"

  test "Getting the shell's history length":
    amount = historyLength(db)
    check:
      updateHistory("test comm", db) == amount + 1

  test "Showing the shell's history":
    check:
     showHistory(db, initLimitedString(capacity = 4, text = "list")) ==
      QuitSuccess

  test "Finding text in the shell's history":
    checkpoint "Finding an exising entry in the history"
    check:
      findInHistory(db, initLimitedString(capacity = 7, text = "find te")) ==
           QuitSuccess
    checkpoint "Finding a non-exising entry in the history"
    check:
      findInHistory(db, initLimitedString(capacity = 8,
          text = "find asd")) == QuitFailure

  test "Clearing the shell's history":
    check:
      clearHistory(db) == 0
      historyLength(db) == 0

  test "Initializing an object of HistoryEntry type":
    check:
      newHistoryEntry(command = "newCom").command == "newCom"

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
