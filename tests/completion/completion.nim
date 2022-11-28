discard """
  exitcode: 0
"""

import os
import ../../src/completion

var completions: seq[string]

open("sometest.txt", fmWrite).close()
getDirCompletion("somete", completions)
removeFile("sometest.txt")
assert completions == @["sometest.txt"], "Failed to get Tab completion."
