import std/tables
import ../src/[commandslist, db, resultcode, themeinit]
import utils/utils
import unittest2

suite "Unit tests for themeinit module":

  checkpoint "Initializing the tests"
  let db = initDb("test17.db")
  var commands = newTable[string, CommandData]()

  test "Initializiation of the shell's theme":
    initTheme(db, commands)
    check:
      commands.len > 0

  test "Showing the theme values":
    check:
      showTheme(db) == QuitSuccess

  test "Asking user for a color":
    when not defined(testInput):
      skip()
    else:
      check:
        askForColor(db, "Testing") != newColor()

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
