discard """
  exitcode: 0
  outputsub: The variable with the Id
"""

import std/[os, strutils, tables]
import ../../src/[commandslist, directorypath, lstring, nish, resultcode, variables]
import norm/sqlite

block:
  assert buildQuery("/".DirectoryPath, "name") ==
      "SELECT name FROM variables WHERE path='/' ORDER BY id ASC", "Failed to build SQL query."

  let db = startDb("test.db".DirectoryPath)
  assert db != nil, "Failed to initialize the database."
  var commands = newTable[string, CommandData]()

  initVariables(db, commands)

  if db.count(Variable) == 0:
    try:
      var variable = newVariable(name = "TESTS", path = "/", recursive = true,
          value = "test_variable", description = "Test variable.")
      db.insert(variable)
      var variable2 = newVariable(name = "TESTS2", path = "/",
          recursive = false, value = "test_variable2",
          description = "Test variable 2.")
      db.insert(variable2)
    except:
      quit QuitFailure
  if db.count(Variable) == 1:
    try:
      var variable = newVariable(name = "TESTS2", path = "/", recursive = false,
          value = "test_variable2", description = "Test variable 2.")
      db.insert(variable)
    except:
      quit QuitFailure

  setVariables("/home".DirectoryPath, db)
  assert getEnv("TESTS") == "test_variable", "Failed to get value of a variable."
  assert not existsEnv("TESTS2"), "Failed to check if variable not exists."

  assert listVariables(initLimitedString(capacity = 4, text = "list"), db) ==
      QuitSuccess, "Failed to show the list of available variables."
  assert listVariables(initLimitedString(capacity = 8, text = "list all"),
      db) == QuitSuccess, "Failed to show the list of all variables."
  assert listVariables(initLimitedString(capacity = 8, text = "werwerew"),
      db) == QuitSuccess, "Failed to show the list of available variables."

  assert deleteVariable(initLimitedString(capacity = 10, text = "delete 123"),
      db) == QuitFailure, "Failed to not delete a non-existing variable."
  assert deleteVariable(initLimitedString(capacity = 10, text = "delete sdf"),
      db) == QuitFailure, "Failed to not delete a non-existing variable with invalid index."
  assert deleteVariable(initLimitedString(capacity = 8, text = "delete 2"),
      db) == QuitSuccess, "Failed to delete a variable."
  assert deleteVariable(initLimitedString(capacity = 8, text = "delete 2"),
      db) == QuitFailure, "Failed to delete a deleted variable."

  assert setCommand(initLimitedString(capacity = 13, text = "test=test_val")) ==
      QuitSuccess, "Failed to set a variable."
  assert getEnv("test") == "test_val", "Failed to get a value of a variable."

  assert unsetCommand(initLimitedString(capacity = 4, text = "test")) ==
      QuitSuccess, "Failed to unset a variable."
  assert getEnv("test") == "", "Failed to not get a value of a non-existing variable."
  assert unsetCommand(initLimitedString(capacity = 4, text = "test")) ==
      QuitSuccess, "Failed to unset a non-existing variable."

  let newVariable = newVariable(name = "ala")
  assert newVariable.name == "ala", "Failed to set a new variable."

  quitShell(ResultCode(QuitSuccess), db)

