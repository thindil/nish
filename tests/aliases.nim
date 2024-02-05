import utils/utils
import unittest2
import ../src/db
{.warning[UnusedImport]:off.}
include ../src/aliases

suite "Unit tests for aliases module":

  checkpoint "Initializing the tests"
  let db = initDb("test2.db")
  var
    myaliases = newOrderedTable[string, int]()
    commands = newTable[string, CommandData]()

  checkpoint "Adding testing aliases if needed"
  db.addAliases

  test "Initialization of the shell's aliases":
    initAliases(db, myaliases, commands)
    check:
      myaliases.len == 1

  test "Getting the shell's alias ID":
    checkpoint "Getting ID of an existing alias"
    check:
      getAliasId("delete 2", db).int == 2
    checkpoint "Getting ID of a non-existing alias"
    check:
      getAliasId("delete 22", db).int == 0

  test "Deleting the shell's alias":
    checkpoint "Deleting an existing alias"
    check:
      deleteAlias("delete 2",
        myaliases, db) == QuitSuccess
      db.count(Alias) == 1
    checkpoint "Deleting a non-existing alias"
    check:
      deleteAlias("delete 22",
        myaliases, db) == QuitFailure
    checkpoint("Re-adding the test alias")
    var testAlias2 = newAlias(name = "tests2", path = "/", recursive = false,
      commands = "ls -a", description = "Test alias 2.", output = "output")
    db.insert(testAlias2)
    unittest2.require:
      db.count(Alias) == 2

  test "Setting the shell's aliases in the current directory":
    myaliases.setAliases(paths.getCurrentDir(), db)
    checkpoint "Checking an existing alias"
    check:
      execAlias("", "tests", myaliases, db) == QuitSuccess
    checkpoint "Checking a non existing alias"
    check:
      execAlias("", "tests2", myaliases, db) == QuitFailure

  test "Listing the shell's aliases":
    checkpoint "List the shell's aliases in the current directory"
    check:
      db.count(Alias) == 2
      listAliases("list", myaliases,
        db) == QuitSuccess
    checkpoint "List all available the shell aliases"
    check:
      listAliases("list all",
        myaliases, db) == QuitSuccess
    checkpoint "Check what happen when invalid argument passed to listAliases"
    expect PreConditionDefect:
      check:
        listAliases("werwerew",
          myaliases, db) == QuitSuccess

  test "Initializing an object of Alias type":
    let newAlias = newAlias(name = "ala")
    check:
      newAlias.name == "ala"

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
