import std/tables
import utils/utils
import ../src/db
import unittest2
include ../src/history

suite "Unit tests for history module":

  checkpoint "Initializing the tests"
  let db = initDb(dbName = "test8.db")
  var commands = newTable[string, CommandData]()

  checkpoint "Initializing the shell's history"
  var amount = initHistory(db = db, commands = commands)
  if amount == 0:
    discard updateHistory(commandToAdd = "alias delete", db = db)

  test "Getting the shell's history entry":
    check:
      getHistory(historyIndex = 1, db = db) == "alias delete"

  test "Getting the shell's history length":
    amount = historyLength(db = db)
    check:
      updateHistory(commandToAdd = "test comm", db = db) == amount + 1

  test "Showing the shell's history":
    check:
     showHistory(db = db, arguments = "list") ==
      QuitSuccess

  test "Finding text in the shell's history":
    checkpoint "Finding an exising entry in the history"
    check:
      findInHistory(db = db, arguments = "find te") ==
           QuitSuccess
    checkpoint "Finding a non-exising entry in the history"
    check:
      findInHistory(db = db, arguments = "find asd") == QuitFailure

  test "Clearing the shell's history":
    check:
      clearHistory(db = db) == 0
      historyLength(db = db) == 0

  test "Initializing an object of HistoryEntry type":
    check:
      newHistoryEntry(command = "newCom").command == "newCom"

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
