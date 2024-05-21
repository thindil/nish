import utils/utils
import ../src/[db, types]
import unittest2
include ../src/title

suite "Unit tests for title module":

  checkpoint "Initializing the tests"
  let db = initDb(dbName = "test9.db")

  test "Set the terminal title":
    setTitle(title = "test title", db = db)

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
