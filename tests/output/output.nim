discard """
  exitcode: 0
"""

import ../../src/[columnamount, output, resultcode]

assert showError("test error") == QuitFailure, "Failed to show error message."

assert getIndent(1.ColumnAmount) == 1

showFormHeader("test header")

showOutput("test output")
