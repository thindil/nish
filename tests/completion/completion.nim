discard """
  exitcode: 0
"""

import os
import ../../src/completion

open("sometest.txt", fmWrite).close()
var completions: seq[string]
getDirCompletion("somete", completions)
assert completions == @["sometest.txt"], "Failed to get Tab completion."
removeFile("sometest.txt")
