import ../src/[db, directorypath, prompt, resultcode]
import unittest2

suite "Unit tests for prompt module":

  checkpoint "Initializing the tests"
  let db = startDb("test14.db".DirectoryPath)
  require:
    db != nil

  test "Getting formated directory name":
    check:
      getFormattedDir().len > 0

  test "Showing the shell's prompt":
    showPrompt(true, "ls -a", QuitSuccess.ResultCode, db)
