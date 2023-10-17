import std/parseopt
import ../src/[constants, input, lstring]
import unittest2

suite "Unit tests for input module":

  test "getArguments":
    var
      userCommand: OptParser = initOptParser("ls -ab --foo --bar=20 file.txt")
      conjCommands: bool = true
      arguments: UserInput = getArguments(userCommand, conjCommands)
    check:
      arguments == initLimitedString(capacity = maxInputLength,
        text = "ls -ab --foo --bar=20 file.txt")

  test "readInput":
    echo "exit"
    check:
      readInput() == initLimitedString(capacity = maxInputLength, text = "exit")

  test "readChar":
    check:
      readChar('c') == "c"
      readChar('H') == "H"

  test "deleteChar":
    var
      inputString = initLimitedString(capacity = maxInputLength, text = "my text")
      cursorPosition: Natural = 1
    deleteChar(inputString, cursorPosition)
    check:
      inputString == "y text"
      cursorPosition == 0

  test "moveCursor":
    let inputString = initLimitedString(capacity = maxInputLength,
        text = "my text")
    var cursorPosition: Natural = 1
    moveCursor('D', cursorPosition, inputString)
    check:
      cursorPosition == 0

  test "updateInput":
    var
      inputString = initLimitedString(capacity = maxInputLength, text = "my text")
      cursorPosition: Natural = 7
    updateInput(cursorPosition, inputString, false, "a")
    check:
      inputString == "my texta"
      cursorPosition == 8
