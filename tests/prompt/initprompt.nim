discard """
  exitcode: 0
"""

import std/[tables]
import ../../src/[constants, prompt]

var
    helpContent = initTable[string, HelpEntry]()
initPrompt(helpContent)
assert helpContent.len() > 0
