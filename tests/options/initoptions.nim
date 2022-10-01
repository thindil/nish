discard """
  exitcode: 0
"""

import std/[tables]
import ../../src/[commandslist, options]

var commands = newTable[string, CommandData]()
initOptions(commands)
assert commands.len() > 0
