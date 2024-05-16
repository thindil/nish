import utils/utils
import unittest2
import ../src/db
include ../src/themeinit

suite "Unit tests for themeinit module":

  checkpoint "Initializing the tests"
  let db = initDb(dbName = "test17.db")
  var commands = newTable[string, CommandData]()

  test "Initializiation of the shell's theme":
    initTheme(db = db, commands = commands)
    check:
      commands.len > 0

  test "Showing the theme values":
    check:
      showTheme(db = db) == QuitSuccess

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
