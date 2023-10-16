import std/[os, strutils, tables]
import ../src/[aliases, completion, commandslist, db, directorypath, lstring, resultcode]
import unittest2
import norm/sqlite

suite "Unit tests for completion module":

  let db = startDb("test5.db".DirectoryPath)
  assert db != nil, "No connection to database."
  var
    myaliases = newOrderedTable[LimitedString, int]()
    commands = newTable[string, CommandData]()
    completions: seq[string]
  if db.count(Alias) == 0:
    try:
      var alias = newAlias(name = "tests", path = "/", recursive = true,
          commands = "ls -a", description = "Test alias.", output = "output")
      db.insert(alias)
    except:
      quit("Can't add test alias.")
    try:
      var testAlias2 = newAlias(name = "tests2", path = "/", recursive = false,
          commands = "ls -a", description = "Test alias 2.", output = "output")
      db.insert(testAlias2)
    except:
      quit("Can't add the second test alias.")
  initAliases(db, myaliases, commands)

  test "getDirCompletion":
    open("sometest.txt", fmWrite).close
    getDirCompletion("somete", completions, db)
    removeFile("sometest.txt")
    check:
      completions == @["sometest.txt"]

  test "getCommandCompletion":
    getCommandCompletion("exi", completions, myaliases, commands, db)
    check:
      completions[1] == "exit"

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
