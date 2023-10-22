import std/[strutils, tables]
import utils/utils
import ../src/[aliases, commands, db, directorypath, lstring, resultcode]
import unittest2
import norm/sqlite

suite "Unit tests for commands module":

  checkpoint "Initializing the tests"
  let db = initDb("test3.db")

  checkpoint "Adding testing aliases if needed"
  if db.count(Alias) == 0:
    var alias = newAlias(name = "tests", path = "/", recursive = true,
        commands = "ls -a", description = "Test alias.", output = "output")
    db.insert(alias)
    var testAlias2 = newAlias(name = "tests2", path = "/", recursive = false,
        commands = "ls -a", description = "Test alias 2.", output = "output")
    db.insert(testAlias2)
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
