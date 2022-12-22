discard """
  exitcode: 0
"""

import ../../src/[directorypath, nish, output, resultcode]

let db = startDb("test.db".DirectoryPath)
assert db != nil, "No connection to database."

assert showError("test error") == QuitFailure, "Failed to show error message."

showFormHeader(message = "test header", db = db)

showOutput("test output")

quitShell(ResultCode(QuitSuccess), db)
