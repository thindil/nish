discard """
  exitcode: 0
  outputsub: test error
"""

import ../../src/[directorypath, nish, output, resultcode]

block:
  let db = startDb("test12.db".DirectoryPath)
  assert db != nil, "No connection to database."

  assert showError("test error") == QuitFailure, "Failed to show error message."

  showFormHeader(message = "test header", db = db)

  showOutput("test output")

  quitShell(ResultCode(QuitSuccess), db)
