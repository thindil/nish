discard """
  exitcode: 0
"""

import ../../src/[nish, directorypath, prompt, resultcode]

let db = startDb("test.db".DirectoryPath)
assert db != nil

assert getFormattedDir().len() > 0
showPrompt(true, "ls -a", ResultCode(QuitSuccess), db)
