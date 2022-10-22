discard """
  exitcode: 0
"""

import ../../src/[output, resultcode]

assert showError("test error") == QuitFailure

showFormHeader("test header")

showOutput("test output")
