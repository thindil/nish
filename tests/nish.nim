when defined(testInput):
  import utils/utils
  import std/tables
  import ../src/[commandslist, history, lstring, resultcode]
import ../src/nish
import unittest2

suite "Unit tests for nish module":

  when defined(testInput):
    checkpoint "Initializing the tests"
    let db = initDb(dbName = "test10.db")
    var
      myaliases = newOrderedTable[LimitedString, int]()
      commands = newTable[string, CommandData]()

  test "Showing the list of available options for the shell":
    showCommandLineHelp()

  test "Showing the shell's version":
    showProgramVersion()

  test "Read the user's input":
    when not defined(testInput):
      skip()
    else:
      var
        iString = ""
        cName = "ls"
        rCode = QuitSuccess.ResultCode
        hIndex: HistoryRange = 1
        cPosition: Natural = 1
      readUserInput(inputString = iString, oneTimeCommand = false, db = db,
          commandName = cName, returnCode = rCode, historyIndex = hIndex,
          cursorPosition = cPosition, aliases = myaliases, commands = commands)
