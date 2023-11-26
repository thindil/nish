import std/tables
import ../src/[db, commandslist, lstring, resultcode]
import utils/utils
import unittest2

suite "Unit tests for db module":

  checkpoint "Initializing the tests"
  let db = initDb("test15.db")
  var commands = newTable[string, CommandData]()

  test "Initialization of the shell's database's commands":
    initDb(db, commands)
    check:
      commands.len == 1

  test "Optimizing the shell's database":
    check:
      optimizeDb(initLimitedString(capacity = 8, text = "optimize"), db) == QuitSuccess

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
