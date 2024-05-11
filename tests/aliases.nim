import utils/utils
import unittest2
import ../src/db
{.warning[UnusedImport]: off.}
include ../src/aliases

suite "Unit tests for aliases module":

  checkpoint "Initializing the tests"
  let db = initDb(dbName = "test2.db")
  var
    myaliases = newOrderedTable[string, int]()
    commands = newTable[string, CommandData]()

  checkpoint "Adding testing aliases if needed"
  db.addAliases

  test "Initialization of the shell's aliases":
    initAliases(db = db, aliases = myaliases, commands = commands)
    check:
      myaliases.len == 1

  test "Getting the shell's alias ID":
    checkpoint "Getting ID of an existing alias"
    check:
      getAliasId(arguments = "delete 2", db = db).int == 2
    checkpoint "Getting ID of a non-existing alias"
    check:
      getAliasId(arguments = "delete 22", db = db).int == 0

  test "Deleting the shell's alias":
    checkpoint "Deleting an existing alias"
    check:
      deleteAlias(arguments = "delete 2", aliases = myaliases, db = db) == QuitSuccess
      db.count(T = Alias) == 1
    checkpoint "Deleting a non-existing alias"
    check:
      deleteAlias(arguments = "delete 22", aliases = myaliases, db = db) == QuitFailure
    checkpoint "Re-adding the test alias"
    var testAlias2 = newAlias(name = "tests2", path = "/".Path,
      recursive = false,
      commands = "ls -a", description = "Test alias 2.", output = "output")
    db.insert(obj = testAlias2)
    unittest2.require:
      db.count(T = Alias) == 2

  test "Setting the shell's aliases in the current directory":
    myaliases.setAliases(directory = paths.getCurrentDir(), db = db)
    checkpoint "Checking an existing alias"
    check:
      execAlias(arguments = "", aliasId = "tests", aliases = myaliases,
          db = db) == QuitSuccess
    checkpoint "Checking a non existing alias"
    check:
      execAlias(arguments = "", aliasId = "tests2", aliases = myaliases,
          db = db) == QuitFailure

  test "Listing the shell's aliases":
    checkpoint "List the shell's aliases in the current directory"
    check:
      db.count(T = Alias) == 2
      listAliases(arguments = "list", aliases = myaliases, db = db) == QuitSuccess
    checkpoint "List all available the shell aliases"
    check:
      listAliases(arguments = "list all", aliases = myaliases, db = db) == QuitSuccess
    checkpoint "Check what happen when invalid argument passed to listAliases"
    expect PreConditionDefect:
      check:
        listAliases(arguments = "werwerew", aliases = myaliases, db = db) == QuitSuccess

  test "Initializing an object of Alias type":
    let newAlias = newAlias(name = "ala")
    check:
      newAlias.name == "ala"

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
