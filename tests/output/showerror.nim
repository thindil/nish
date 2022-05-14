discard """
  exitcode: 0
"""

import ../../src/[constants, output]

assert showError("test error") == QuitFailure
