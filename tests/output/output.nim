discard """
  exitcode: 0
"""

import ../../src/[output, resultcode]

assert showError("test error") == QuitFailure, "Failed to show error message."

showFormHeader("test header")

showOutput("test output")
