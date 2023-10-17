import std/tables
import ../src/[commandslist, directorypath, db, history, lstring, resultcode]
import unittest2

suite "Unit tests for history module":

  let db = startDb("test8.db".DirectoryPath)
  assert db != nil, "Failed to initialize the database."
  var commands = newTable[string, CommandData]()
  var amount = initHistory(db, commands)
  if amount == 0:
    discard updateHistory("alias delete", db)

  test "getHistory":
    check:
      getHistory(1, db) == "alias delete"

  test "historyLength":
    amount = historyLength(db)
    check:
      updateHistory("test comm", db) == amount + 1

  test "showHistory":
    check:
     showHistory(db, initLimitedString(capacity = 4, text = "list")) ==
      QuitSuccess

  test "findInHistory":
    check:
      findInHistory(db, initLimitedString(capacity = 7, text = "find te")) ==
           QuitSuccess
      findInHistory(db, initLimitedString(capacity = 8,
          text = "find asd")) == QuitFailure

  test "clearHistory":
    check:
      clearHistory(db) == 0
      historyLength(db) == 0

  test "newHistoryEntry":
    check:
      newHistoryEntry(command = "newCom").command == "newCom"

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
