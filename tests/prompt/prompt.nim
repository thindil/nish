discard """
  exitcode: 0
"""

import ../../src/[nish, directorypath, prompt, resultcode]

let db = startDb("test.db".DirectoryPath)
assert db != nil, "Failed to initialize the database."

assert getFormattedDir().len > 0, "Failed to get formatted current directory path."
showPrompt(true, "ls -a", ResultCode(QuitSuccess), db)
