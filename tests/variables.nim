import std/[os, strutils, tables]
import ../src/[commandslist, directorypath, db, lstring, resultcode, variables]
import norm/sqlite
import unittest2

suite "Unit tests for variable modules":

  let db = startDb("test.db".DirectoryPath)
  assert db != nil, "Failed to initialize the database."
  var commands = newTable[string, CommandData]()
  initVariables(db, commands)
  if db.count(Variable) == 0:
    var variable = newVariable(name = "TESTS", path = "/", recursive = true,
          value = "test_variable", description = "Test variable.")
    db.insert(variable)
    var variable2 = newVariable(name = "TESTS2", path = "/",
        recursive = false, value = "test_variable2",
        description = "Test variable 2.")
    db.insert(variable2)
  if db.count(Variable) == 1:
    var variable = newVariable(name = "TESTS2", path = "/", recursive = false,
        value = "test_variable2", description = "Test variable 2.")
    db.insert(variable)

  test "buildQuery":
    check:
      buildQuery("/".DirectoryPath, "name") ==
      "SELECT name FROM variables WHERE path='/' ORDER BY id ASC"

  test "setVariables":
    setVariables("/home".DirectoryPath, db)

  test "getEnv":
    check:
      getEnv("TESTS") == "test_variable"

  test "existsEnv":
    check:
      not existsEnv("TESTS2")

  test "listVariables":
    check:
      listVariables(initLimitedString(capacity = 4, text = "list"), db) ==
          QuitSuccess
      listVariables(initLimitedString(capacity = 8, text = "list all"),
          db) == QuitSuccess
      listVariables(initLimitedString(capacity = 8, text = "werwerew"),
          db) == QuitSuccess

  test "deleteVariable":
    check:
      deleteVariable(initLimitedString(capacity = 10, text = "delete 123"),
          db) == QuitFailure
      deleteVariable(initLimitedString(capacity = 10, text = "delete sdf"),
          db) == QuitFailure
      deleteVariable(initLimitedString(capacity = 8, text = "delete 2"),
          db) == QuitSuccess
      deleteVariable(initLimitedString(capacity = 8, text = "delete 2"),
          db) == QuitFailure

  test "setCommand":
    check:
      setCommand(initLimitedString(capacity = 13, text = "test=test_val")) ==
          QuitSuccess
      getEnv("test") == "test_val"

  test "unsetCommand":
    check:
      unsetCommand(initLimitedString(capacity = 4, text = "test")) ==
          QuitSuccess
      getEnv("test") == ""
      unsetCommand(initLimitedString(capacity = 4, text = "test")) ==
          QuitSuccess

  test "newVariable":
    let newVariable = newVariable(name = "ala")
    check:
      newVariable.name == "ala"

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
