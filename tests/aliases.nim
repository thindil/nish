import std/[os, strutils, tables]
import ../src/[aliases, db, directorypath, commandslist, lstring, resultcode]
import contracts, unittest2
import norm/sqlite

suite "Unit tests for aliases module":

  let db = startDb("test2.db".DirectoryPath)
  assert db != nil, "No connection to database."
  var
    myaliases = newOrderedTable[LimitedString, int]()
    commands = newTable[string, CommandData]()

  if db.count(Alias) == 0:
    var alias = newAlias(name = "tests", path = "/", recursive = true,
          commands = "ls -a", description = "Test alias.", output = "output")
    db.insert(alias)
    var testAlias2 = newAlias(name = "tests2", path = "/", recursive = false,
        commands = "ls -a", description = "Test alias 2.", output = "output")
    db.insert(testAlias2)

  test "initAliases":
    initAliases(db, myaliases, commands)
    check:
      myaliases.len == 1

  test "deleteAlias":
    check:
      deleteAlias(initLimitedString(capacity = 8, text = "delete 2"),
        myaliases, db) == QuitSuccess
      db.count(Alias) == 1
      deleteAlias(initLimitedString(capacity = 9, text = "delete 22"),
        myaliases, db) == QuitFailure
    var testAlias2 = newAlias(name = "tests2", path = "/", recursive = false,
      commands = "ls -a", description = "Test alias 2.", output = "output")
    db.insert(testAlias2)
    unittest2.require:
      db.count(Alias) == 2

  test "setAliases":
    myaliases.setAliases(getCurrentDir().DirectoryPath, db)
    check:
      execAlias(emptyLimitedString(), "tests", myaliases, db) == QuitSuccess
      execAlias(emptyLimitedString(), "tests2", myaliases, db) == QuitFailure

  test "listAliases":
    check:
      db.count(Alias) == 2
      listAliases(initLimitedString(capacity = 4, text = "list"), myaliases,
        db) == QuitSuccess
      listAliases(initLimitedString(capacity = 8, text = "list all"),
        myaliases, db) == QuitSuccess
    try:
      check:
        listAliases(initLimitedString(capacity = 8, text = "werwerew"),
          myaliases, db) == QuitSuccess
    except PreConditionDefect:
      discard

  test "newAlias":
    let newAlias = newAlias(name = "ala")
    check:
      newAlias.name == "ala"

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
