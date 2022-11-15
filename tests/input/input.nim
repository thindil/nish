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
    text = "ls -a -b --foo --bar=20 file.txt"), "Failed to set the argumets."

assert readInput() == initLimitedString(capacity = maxInputLength, text = "exit")

assert readChar('c') == "c", "Failed to read a character from the input."
assert readChar('H') == "H", "Failed to read a upper character from the input."

block:
  var
    inputString = initLimitedString(capacity = maxInputLength, text = "my text")
    cursorPosition: Natural = 1
  deleteChar(inputString, cursorPosition)
  assert inputString == "y text", "Failed to delete character from the input."
  assert cursorPosition == 0, "Failed to get cursor position after deleting a character."

block:
  let inputString = initLimitedString(capacity = maxInputLength,
      text = "my text")
  var cursorPosition: Natural = 1
  moveCursor('D', cursorPosition, inputString)
  assert cursorPosition == 0, "Failed to move the cursor back in the input."

block:
  var
    inputString = initLimitedString(capacity = maxInputLength, text = "my text")
    cursorPosition: Natural = 7
  updateInput(cursorPosition, inputString, false, "a")
  assert inputString == "my texta", "Failed to insert a character at the end of the input."
  assert cursorPosition == 8, "Failed to get the cursor position after inserting a character."
