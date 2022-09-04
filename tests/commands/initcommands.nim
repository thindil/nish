discard """
  exitcode: 0
"""

import std/tables
import ../../src/[commands, constants]

var helpContent = newTable[string, HelpEntry]()
initCommands(helpContent)
assert helpContent.len() == 4
