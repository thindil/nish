import std/[os, strutils, tables]
import utils/utils
import ../src/[commandslist, directorypath, db, lstring, resultcode, variables]
import norm/sqlite
import unittest2

suite "Unit tests for variable modules":

  checkpoint "Initializing the tests"
  let db = initDb("test.db")
  var commands = newTable[string, CommandData]()

  initVariables(db, commands)
  checkpoint "Adding testing variables if needed"
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

  test "Building a SQL query":
    check:
      buildQuery("/".DirectoryPath, "name") ==
      "SELECT name FROM variables WHERE path='/' ORDER BY id ASC"

  test "Setting variables in the selected directory":
    setVariables("/home".DirectoryPath, db)

  test "Getting an environment variable":
    check:
      getEnv("TESTS") == "test_variable"

  test "Checking do an environment variable exists":
    check:
      not existsEnv("TESTS2")

  test "Showing environment variables":
    checkpoint "Showing available environment variables"
    check:
      listVariables(initLimitedString(capacity = 4, text = "list"), db) ==
          QuitSuccess
    checkpoint "Showing all environment variables"
    check:
      listVariables(initLimitedString(capacity = 8, text = "list all"),
          db) == QuitSuccess
    checkpoint "Showing environment variables with invalid subcommand"
    check:
      listVariables(initLimitedString(capacity = 8, text = "werwerew"),
          db) == QuitSuccess

  test "Deleting an environment variable":
    checkpoint "Deleting a non-existing environment variable"
    check:
      deleteVariable(initLimitedString(capacity = 10, text = "delete 123"),
          db) == QuitFailure
    checkpoint "Deleting a non-existing environment variable with invalid index"
    check:
      deleteVariable(initLimitedString(capacity = 10, text = "delete sdf"),
          db) == QuitFailure
    checkpoint "Deleting an existing environment variable"
    check:
      deleteVariable(initLimitedString(capacity = 8, text = "delete 2"),
          db) == QuitSuccess
    checkpoint "Deleting a previously deleted environment variable"
    check:
      deleteVariable(initLimitedString(capacity = 8, text = "delete 2"),
          db) == QuitFailure

  test "Setting an evironment variable":
    check:
      setCommand(initLimitedString(capacity = 13, text = "test=test_val")) ==
          QuitSuccess
      getEnv("test") == "test_val"

  test "Unsetting an environment variable":
    checkpoint "Unsetting an existing environment variable"
    check:
      unsetCommand(initLimitedString(capacity = 4, text = "test")) ==
          QuitSuccess
      getEnv("test") == ""
    checkpoint "Unsetting an non-existing environment variable"
    check:
      unsetCommand(initLimitedString(capacity = 4, text = "test")) ==
          QuitSuccess

  test "Initializing an object of Variable type":
    let newVariable = newVariable(name = "ala")
    check:
      newVariable.name == "ala"

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
