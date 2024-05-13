import utils/utils
import ../src/db
import unittest2
include ../src/prompt

suite "Unit tests for prompt module":

  checkpoint "Initializing the tests"
  let db = initDb(dbName = "test14.db")

  test "Getting formated directory name":
    check:
      getFormattedDir().string.len > 0

  test "Showing the shell's prompt":
    showPrompt(promptEnabled = true, previousCommand = "ls -a",
        resultCode = QuitSuccess.ResultCode, db = db)

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
