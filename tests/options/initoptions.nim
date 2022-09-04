discard """
  exitcode: 0
"""

import std/[tables]
import ../../src/[constants, options]

var helpContent = newTable[string, HelpEntry]()
initOptions(helpContent)
assert helpContent.len() > 0
