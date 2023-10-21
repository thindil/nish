import ../src/[db, directorypath, output, resultcode]
import unittest2

suite "Unit tests for output module":

  checkpoint "Initializing the tests"
  let db = startDb("test12.db".DirectoryPath)
  require:
    db != nil

  test "Showing an error message":
    check:
      showError("test error") == QuitFailure

  test "Drawing a form's header":
    showFormHeader(message = "test header", db = db)

  test "Showing a normal output":
    showOutput("test output")

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
