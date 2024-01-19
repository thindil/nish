import std/tables
import utils/utils
import ../src/[db, commandslist, highlight, resultcode, constants]
import unittest2

suite "Unit tests for highlight module":

  checkpoint "Initializing the tests"
  let db = initDb("test7.db")
  var
    myaliases = newOrderedTable[string, int]()
    commands = newTable[string, CommandData]()
    inputString: UserInput = "test"

  test "Highlighting the shell's output":
    highlightOutput(0, inputString, commands, myaliases, false, "",
        QuitSuccess.ResultCode, db, 0, true)

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
