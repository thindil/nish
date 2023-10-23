import std/[os, tables]
import utils/utils
import ../src/[aliases, completion, commandslist, db, lstring, resultcode]
import unittest2

suite "Unit tests for completion module":

  checkpoint "Initializing the tests"
  let db = initDb("test5.db")
  var
    myaliases = newOrderedTable[LimitedString, int]()
    commands = newTable[string, CommandData]()
    completions: seq[string]

  checkpoint "Adding testing aliases if needed"
  db.addAliases
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
