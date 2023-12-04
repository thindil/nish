import std/parseopt
import utils/utils
import ../src/[constants, input, lstring]
import unittest2

suite "Unit tests for input module":

  checkpoint "Initializing the tests"
  let db = initDb("test8.db")

  test "Getting the command's arguments":
    var
      userCommand: OptParser = initOptParser("ls -ab --foo --bar=20 file.txt")
      conjCommands: bool = true
      arguments: UserInput = getArguments(userCommand, conjCommands)
    check:
      arguments == initLimitedString(capacity = maxInputLength,
        text = "ls -ab --foo --bar=20 file.txt")

  test "Reading the user's input":
    when not defined(testInput):
      skip()
    else:
      echo "exit"
      check:
        readInput() == initLimitedString(capacity = maxInputLength, text = "exit")

  test "Reading a character from the user's input":
    checkpoint "Reading a lowercase character"
    check:
      readChar('c', db) == "c"
    checkpoint "Reading a uppercase character"
    check:
      readChar('H', db) == "H"

  test "Deleting a character":
    var
      inputString = initLimitedString(capacity = maxInputLength, text = "my text")
      cursorPosition: Natural = 1
    deleteChar(inputString, cursorPosition, db)
    check:
      inputString == "y text"
      cursorPosition == 0

  test "Moving the cursor":
    let inputString = initLimitedString(capacity = maxInputLength,
        text = "my text")
    var cursorPosition: Natural = 1
    moveCursor('D', cursorPosition, inputString, db)
    check:
      cursorPosition == 0

  test "Updating the user's input":
    var
      inputString = initLimitedString(capacity = maxInputLength, text = "my text")
      cursorPosition: Natural = 7
    updateInput(cursorPosition, inputString, false, "a", db)
    check:
      inputString == "my texta"
      cursorPosition == 8
