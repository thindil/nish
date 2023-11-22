import std/[os, tables]
import utils/utils
import ../src/[aliases, completion, commandslist, db, lstring, resultcode]
import norm/sqlite
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

  checkpoint "Adding a test completion"
  if db.count(Completion) == 0:
    var completion = newCompletion(command = "ala", cType = custom,
        cValues = "something")
    db.insert(completion)

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

  test "Initializing an object of Completion type":
    let newCompletion = newCompletion(command = "ala")
    check:
      newCompletion.command == "ala"

  test "Get completion for a command's argument":
    getCompletion("ala", "some", completions, myaliases, commands, db)
    check:
      completions[0] == "something"

  test "Listing the defined commands' completions":
    check:
      listCompletion(initLimitedString(capacity = 4, text = "list"), db) == QuitSuccess

  test "Deleting a commands' completion":
    checkpoint "Deleting an existing completion"
    check:
      deleteCompletion(initLimitedString(capacity = 8, text = "delete 1"), db) == QuitSuccess
      db.count(Completion) == 0
    var completion = newCompletion(command = "ala", cType = custom,
        cValues = "something")
    db.insert(completion)
    checkpoint "Deleting a non-existing completion"
    check:
      deleteCompletion(initLimitedString(capacity = 8, text = "delete 2"), db) == QuitFailure
      db.count(Completion) == 1

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
