import std/[strutils, tables]
import ../src/[aliases, commands, db, directorypath, lstring, resultcode]
import unittest2
import norm/sqlite

suite "Unit tests for commands module":

  let db = startDb("test3.db".DirectoryPath)
  assert db != nil, "Failed to initialize database."
  if db.count(Alias) == 0:
    var alias = newAlias(name = "tests", path = "/", recursive = true,
        commands = "ls -a", description = "Test alias.", output = "output")
    db.insert(alias)
    var testAlias2 = newAlias(name = "tests2", path = "/", recursive = false,
        commands = "ls -a", description = "Test alias 2.", output = "output")
    db.insert(testAlias2)
  var myaliases = newOrderedTable[LimitedString, int]()

  test "cdCommand":
    check:
      cdCommand("/".DirectoryPath, myaliases, db) == QuitSuccess
      cdCommand("/adfwerewtr".DirectoryPath, myaliases, db) == QuitFailure

  test "changeDirectory":
    check:
      changeDirectory("..".DirectoryPath, myaliases, db) == QuitSuccess
      changeDirectory("/adfwerewtr".DirectoryPath, myaliases, db) == QuitFailure

  suiteTeardown:
    quitShell(QuitSuccess.ResultCode, db)
