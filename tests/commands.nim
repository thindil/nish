import utils/utils
import unittest2
import ../src/db
include ../src/commands

suite "Unit tests for commands module":

  checkpoint "Initializing the tests"
  let db = initDb(dbName = "test3.db")

  checkpoint "Adding testing aliases if needed"
  db.addAliases
  var myaliases = newOrderedTable[string, int]()

  test "Testing cd command":
    checkpoint "Entering an existing directory"
    check:
      cdCommand(newDirectory = "/".Path, aliases = myaliases, db = db) == QuitSuccess
    checkpoint "Trying to enter a non-existing directory"
    check:
      cdCommand(newDirectory = "/adfwerewtr".Path, aliases = myaliases,
          db = db) == QuitFailure

  test "Testing changing the current directory of the shell":
    checkpoint "Changing the current directory"
    check:
      changeDirectory(newDirectory = "..".Path, aliases = myaliases, db = db) == QuitSuccess
    checkpoint "Changing the current directory to non-existing directory"
    check:
      changeDirectory(newDirectory = "/adfwerewtr".Path, aliases = myaliases,
          db = db) == QuitFailure

  test "Executing a command":
    var
      cursorPosition: Natural = 1
      commands = newTable[string, CommandData]()
    check:
      executeCommand(commands = commands, commandName = "ls",
          arguments = "-a .", inputString = "ls -a .", db = db,

aliases = myaliases, cursorPosition = cursorPosition) == QuitSuccess

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
