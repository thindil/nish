import std/parseopt
import ../src/[constants, input, lstring]
import unittest2

suite "Unit tests for input module":

  test "Getting the command's arguments":
    var
      userCommand: OptParser = initOptParser("ls -ab --foo --bar=20 file.txt")
      conjCommands: bool = true
      arguments: UserInput = getArguments(userCommand, conjCommands)
    check:
      arguments == initLimitedString(capacity = maxInputLength,
        text = "ls -ab --foo --bar=20 file.txt")

  test "Reading the user's input":
    if stdin != nil:
      return
    echo "exit"
    check:
      readInput() == initLimitedString(capacity = maxInputLength, text = "exit")

  test "Reading a character from the user's input":
    checkpoint "Reading a lowercase character"
    check:
      readChar('c') == "c"
    checkpoint "Reading a uppercase character"
    check:
      readChar('H') == "H"

  test "Deleting a character":
    var
      inputString = initLimitedString(capacity = maxInputLength, text = "my text")
      cursorPosition: Natural = 1
    deleteChar(inputString, cursorPosition)
    check:
      inputString == "y text"
      cursorPosition == 0

  test "Moving the cursor":
    let inputString = initLimitedString(capacity = maxInputLength,
        text = "my text")
    var cursorPosition: Natural = 1
    moveCursor('D', cursorPosition, inputString)
    check:
      cursorPosition == 0

  test "Updating the user's input":
    var
      inputString = initLimitedString(capacity = maxInputLength, text = "my text")
      cursorPosition: Natural = 7
    updateInput(cursorPosition, inputString, false, "a")
    check:
      inputString == "my texta"
      cursorPosition == 8
