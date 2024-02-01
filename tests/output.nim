when defined(testInput):
  import std/tables
import utils/utils
import ../src/db
import unittest2
include ../src/output

suite "Unit tests for output module":

  checkpoint "Initializing the tests"
  let db = initDb("test12.db")

  test "Showing an error message":
    check:
      showError("test error", db = db) == QuitFailure

  test "Drawing a form's header":
    showFormHeader(message = "test header", db = db)

  test "Showing a normal output":
    showOutput("test output", db = db)

  test "Showing options to select":
    when not defined(testInput):
      skip()
    else:
      check:
        selectOption({'a': "option1", 'b': "option2"}.toTable, 'a', "Option", db) == 'a'

  test "Showing confirmation prompt":
    when not defined(testInput):
      skip()
    else:
      check:
        confirm("Confirm", db)

  test "Showing a form's prompt":
    showFormPrompt("Form prompt", db)

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
