discard """
  exitcode: 0
"""

import ../../src/output

assert showError("test error") == QuitFailure
