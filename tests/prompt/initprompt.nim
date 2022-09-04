discard """
  exitcode: 0
"""

import std/[tables]
import ../../src/[constants, prompt]

var helpContent = newTable[string, HelpEntry]()
initPrompt(helpContent)
assert helpContent.len() > 0
