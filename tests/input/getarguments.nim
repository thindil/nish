discard """
  exitcode: 0
"""

import std/parseopt
import ../../src/[constants, input]

var
  userCommand: OptParser = initOptParser("ls -ab --foo --bar=20 file.txt")
  conjCommands: bool = true
  arguments: UserInput = getArguments(userCommand, conjCommands)

assert arguments == "ls -a -b --foo --bar=20 file.txt"
