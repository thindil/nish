discard """
  exitcode: 0
"""

import std/parseopt
import ../../src/[constants, input, lstring]

var
  userCommand: OptParser = initOptParser("ls -ab --foo --bar=20 file.txt")
  conjCommands: bool = true
  arguments: UserInput = getArguments(userCommand, conjCommands)

assert arguments == initLimitedString(capacity = maxInputLength,
    text = "ls -a -b --foo --bar=20 file.txt")

assert readInput() == initLimitedString(capacity = maxInputLength, text = "exit")
