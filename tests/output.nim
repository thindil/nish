import ../src/[db, directorypath, output, resultcode]
import unittest2

suite "Unit tests for output module":

  let db = startDb("test12.db".DirectoryPath)
  assert db != nil, "No connection to database."

  test "showError":
    check:
      showError("test error") == QuitFailure

  test "showFormHeader":
    showFormHeader(message = "test header", db = db)

  test "showOutput":
    showOutput("test output")

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
