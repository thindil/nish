import std/tables
import utils/utils
import ../src/[commands, db, directorypath, lstring, resultcode]
import unittest2

suite "Unit tests for commands module":

  checkpoint "Initializing the tests"
  let db = initDb("test3.db")

  checkpoint "Adding testing aliases if needed"
  db.addAliases
  var myaliases = newOrderedTable[LimitedString, int]()

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

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
