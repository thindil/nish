import std/[os, strutils, tables]
import ../src/[aliases, db, directorypath, commandslist, lstring, resultcode]
import utils/utils
import contracts, unittest2
import norm/sqlite

suite "Unit tests for aliases module":

  checkpoint "Initializing the tests"
  let db = initDb("test2.db")
  var
    myaliases = newOrderedTable[LimitedString, int]()
    commands = newTable[string, CommandData]()

  checkpoint "Adding testing aliases if needed"
  if db.count(Alias) == 0:
    var alias = newAlias(name = "tests", path = "/", recursive = true,
          commands = "ls -a", description = "Test alias.", output = "output")
    db.insert(alias)
    var testAlias2 = newAlias(name = "tests2", path = "/", recursive = false,
        commands = "ls -a", description = "Test alias 2.", output = "output")
    db.insert(testAlias2)

  test "Initialization of the shell's aliases":
    initAliases(db, myaliases, commands)
    check:
      myaliases.len == 1

  test "Deleting the shell's alias":
    checkpoint "Deleting an existing alias"
    check:
      deleteAlias(initLimitedString(capacity = 8, text = "delete 2"),
        myaliases, db) == QuitSuccess
      db.count(Alias) == 1
    checkpoint "Deleting a non-existing alias"
    check:
      deleteAlias(initLimitedString(capacity = 9, text = "delete 22"),
        myaliases, db) == QuitFailure
    checkpoint("Readding the test alias")
    var testAlias2 = newAlias(name = "tests2", path = "/", recursive = false,
      commands = "ls -a", description = "Test alias 2.", output = "output")
    db.insert(testAlias2)
    unittest2.require:
      db.count(Alias) == 2

  test "Setting the shell's aliases in the current directory":
    myaliases.setAliases(getCurrentDir().DirectoryPath, db)
    checkpoint "Checking an existing alias"
    check:
      execAlias(emptyLimitedString(), "tests", myaliases, db) == QuitSuccess
    checkpoint "Checking a non existing alias"
    check:
      execAlias(emptyLimitedString(), "tests2", myaliases, db) == QuitFailure

  test "Listing the shell's aliases":
    checkpoint "List the shell's aliases in the current directory"
    check:
      db.count(Alias) == 2
      listAliases(initLimitedString(capacity = 4, text = "list"), myaliases,
        db) == QuitSuccess
    checkpoint "List all available the shell aliases"
    check:
      listAliases(initLimitedString(capacity = 8, text = "list all"),
        myaliases, db) == QuitSuccess
    checkpoint "Check what happen when invalid argument passed to listAliases"
    expect PreConditionDefect:
      check:
        listAliases(initLimitedString(capacity = 8, text = "werwerew"),
          myaliases, db) == QuitSuccess

  test "Initializing an object of Alias type":
    let newAlias = newAlias(name = "ala")
    check:
      newAlias.name == "ala"

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
