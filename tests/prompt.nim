import utils/utils
import ../src/[directorypath, prompt, resultcode]
import unittest2

suite "Unit tests for prompt module":

  checkpoint "Initializing the tests"
  let db = initDb("test14.db")

  test "Getting formated directory name":
    check:
      getFormattedDir().len > 0

  test "Showing the shell's prompt":
    showPrompt(true, "ls -a", QuitSuccess.ResultCode, db)
