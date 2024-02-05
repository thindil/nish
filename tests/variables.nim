import utils/utils
import ../src/db
import unittest2
{.warning[UnusedImport]:off.}
include ../src/variables

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
      buildQuery("/".Path, "name") ==
      "SELECT name FROM variables WHERE path='/' ORDER BY id ASC"

  test "Setting variables in the selected directory":
    setVariables("/home".Path, db)

  test "Getting an environment variable":
    check:
      getEnv("TESTS") == "test_variable"

  test "Checking do an environment variable exists":
    check:
      not existsEnv("TESTS2")

  test "Getting the environment variable ID":
    checkpoint "Getting ID of an existing variable"
    check:
      getVariableId("delete 2",
          db).int == 2
    checkpoint "Getting ID of a non-existing variable"
    check:
      getVariableId("delete 22",
          db).int == 0

  test "Showing environment variables":
    checkpoint "Showing available environment variables"
    check:
      listVariables("list", db) ==
          QuitSuccess
    checkpoint "Showing all environment variables"
    check:
      listVariables("list all",
          db) == QuitSuccess
    checkpoint "Showing environment variables with invalid subcommand"
    check:
      listVariables("werwerew",
          db) == QuitSuccess

  test "Deleting an environment variable":
    checkpoint "Deleting a non-existing environment variable"
    check:
      deleteVariable("delete 123",
          db) == QuitFailure
    checkpoint "Deleting a non-existing environment variable with invalid index"
    check:
      deleteVariable("delete sdf",
          db) == QuitFailure
    checkpoint "Deleting an existing environment variable"
    check:
      deleteVariable("delete 2",
          db) == QuitSuccess
    checkpoint "Deleting a previously deleted environment variable"
    check:
      deleteVariable("delete 2",
          db) == QuitFailure

  test "Setting an evironment variable":
    check:
      setCommand("test=test_val",
          db = db) ==
          QuitSuccess
      getEnv("test") == "test_val"

  test "Unsetting an environment variable":
    checkpoint "Unsetting an existing environment variable"
    check:
      unsetCommand("test", db = db) ==
          QuitSuccess
      getEnv("test") == ""
    checkpoint "Unsetting an non-existing environment variable"
    check:
      unsetCommand("test", db = db) ==
          QuitSuccess

  test "Initializing an object of Variable type":
    let newVariable = newVariable(name = "ala")
    check:
      newVariable.name == "ala"

  test "Getting the type of the database field for VariableValType":
    check:
      dbType(VariableValType) == "TEXT"

  test "Converting dbValue to VariableValType":
    check:
      dbValue(text).s == "text"

  test "Converting VariableValType to dbValue":
    check:
      to(text.dbValue, VariableValType) == text

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
