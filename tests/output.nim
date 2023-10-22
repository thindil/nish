import utils/utils
import ../src/[db, output, resultcode]
import unittest2

suite "Unit tests for output module":

  checkpoint "Initializing the tests"
  let db = initDb("test12.db")

  test "Showing an error message":
    check:
      showError("test error") == QuitFailure

  test "Drawing a form's header":
    showFormHeader(message = "test header", db = db)

  test "Showing a normal output":
    showOutput("test output")

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
