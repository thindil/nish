import utils/utils
import std/tables
import ../src/[commandslist, history, lstring, nish, resultcode]
import unittest2

suite "Unit tests for nish module":

  checkpoint "Initializing the tests"
  let db = initDb("test10.db")
  var
    myaliases = newOrderedTable[LimitedString, int]()
    commands = newTable[string, CommandData]()

  test "Showing the list of available options for the shell":
    showCommandLineHelp()

  test "Showing the shell's version":
    showProgramVersion()

  test "Read the user's input":
    if stdin == nil:
      return
    var
      iString = initLimitedString(capacity = 100, text = "")
      cName = "ls"
      rCode = QuitSuccess.ResultCode
      hIndex: HistoryRange = 1
      cPosition: Natural = 1
    readUserInput(iString, false, db, cName, rCode, hIndex, cPosition,
        myaliases, commands)
