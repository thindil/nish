import ../src/[db, directorypath, prompt, resultcode]
import unittest2

suite "Unit tests for prompt module":

  let db = startDb("test14.db".DirectoryPath)
  assert db != nil, "Failed to initialize the database."

  test "getFormattedDir":
    check:
      getFormattedDir().len > 0

  test "showPrompt":
    showPrompt(true, "ls -a", QuitSuccess.ResultCode, db)
