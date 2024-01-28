import utils/utils
import unittest2
import ../src/db
{.warning[UnusedImport]:off.}
include ../src/commands

suite "Unit tests for commands module":

  checkpoint "Initializing the tests"
  let db = initDb("test3.db")

  checkpoint "Adding testing aliases if needed"
  db.addAliases
  var myaliases = newOrderedTable[string, int]()

  test "Testing cd command":
    checkpoint "Entering an existing directory"
    check:
      cdCommand("/".DirectoryPath, myaliases, db) == QuitSuccess
    checkpoint "Trying to enter a non-existing directory"
    check:
      cdCommand("/adfwerewtr".DirectoryPath, myaliases, db) == QuitFailure

  test "Testing changing the current directory of the shell":
    checkpoint "Changing the current directory"
    check:
      changeDirectory("..".DirectoryPath, myaliases, db) == QuitSuccess
    checkpoint "Changing the current directory to non-existing directory"
    check:
      changeDirectory("/adfwerewtr".DirectoryPath, myaliases, db) == QuitFailure

  test "Executing a command":
    var
      cursorPosition: Natural = 1
      commands = newTable[string, CommandData]()
    check:
      executeCommand(commands, "ls", "-a .", "ls -a .", db,
          myaliases, cursorPosition) == QuitSuccess

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
