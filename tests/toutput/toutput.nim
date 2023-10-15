discard """
  exitcode: 0
  outputsub: test error
"""

import ../../src/[db, directorypath, output, resultcode]

block:
  let db = startDb("test12.db".DirectoryPath)
  assert db != nil, "No connection to database."

  assert showError("test error") == QuitFailure, "Failed to show error message."

  showFormHeader(message = "test header", db = db)

  showOutput("test output")

  closeDb(ResultCode(QuitSuccess), db)
