discard """
  exitcode: 0
  outputsub: /
"""

import ../../src/[db, directorypath, prompt, resultcode]

block:
  let db = startDb("test14.db".DirectoryPath)
  assert db != nil, "Failed to initialize the database."

  assert getFormattedDir().len > 0, "Failed to get formatted current directory path."
  showPrompt(true, "ls -a", ResultCode(QuitSuccess), db)
