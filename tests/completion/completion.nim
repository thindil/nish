discard """
  exitcode: 0
"""

import os
import ../../src/completion

open("sometest.txt", fmWrite).close()
assert getDirCompletion("somete") == @["sometest.txt"], "Failed to get Tab completion."
removeFile("sometest.txt")
