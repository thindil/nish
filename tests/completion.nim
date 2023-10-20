import std/[os, strutils, tables]
import ../src/[aliases, completion, commandslist, db, directorypath, lstring, resultcode]
import unittest2
import norm/sqlite

suite "Unit tests for completion module":

  checkpoint "Initializing the tests"
  let db = startDb("test5.db".DirectoryPath)
  require:
    db != nil
  var
    myaliases = newOrderedTable[LimitedString, int]()
    commands = newTable[string, CommandData]()
    completions: seq[string]

  checkpoint "Adding testing aliases if needed"
  if db.count(Alias) == 0:
    var alias = newAlias(name = "tests", path = "/", recursive = true,
        commands = "ls -a", description = "Test alias.", output = "output")
    db.insert(alias)
    var testAlias2 = newAlias(name = "tests2", path = "/", recursive = false,
        commands = "ls -a", description = "Test alias 2.", output = "output")
    db.insert(testAlias2)
  initAliases(db, myaliases, commands)

  test "Get completion for a file name":
    open("sometest.txt", fmWrite).close
    getDirCompletion("somete", completions, db)
    removeFile("sometest.txt")
    check:
      completions == @["sometest.txt"]

  test "Get completion for a command":
    getCommandCompletion("exi", completions, myaliases, commands, db)
    check:
      completions[1] == "exit"

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
