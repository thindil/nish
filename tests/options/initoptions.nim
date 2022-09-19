discard """
  exitcode: 0
"""

import std/[tables]
import ../../src/[commandslist, constants, options]

var
  helpContent = newTable[string, HelpEntry]()
  commands: CommandsList = initTable[string, CommandData]()
initOptions(helpContent, commands)
assert helpContent.len() > 0
