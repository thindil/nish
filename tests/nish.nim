import std/tables
import utils/utils
import ../src/[commandslist, lstring, nish, resultcode]
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

  test "Executing a command":
    var cursorPosition: Natural = 1
    check:
      executeCommand(commands, "ls", initLimitedString(capacity = 4,
          text = "-a ."), initLimitedString(capacity = 7, text = "ls -a ."), db,
          myaliases, cursorPosition) == QuitSuccess
