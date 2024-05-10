import utils/utils
import unittest2
include ../src/input
when defined(testInput):
  import ../src/theme
  import nimalyzer

suite "Unit tests for input module":

  checkpoint "Initializing the tests"
  let db: DbConn = initDb(dbName = "test8.db")

  test "Getting the command's arguments":
    var
      userCommand: OptParser = initOptParser(
          cmdline = "ls -ab --foo --bar=20 file.txt")
      conjCommands: bool = true
      arguments: UserInput = getArguments(userInput = userCommand,
          conjCommands = conjCommands)
    check:
      arguments == "ls -ab --foo --bar=20 file.txt"

  test "Reading the user's input":
    when not defined(testInput):
      skip()
    else:
      echo "exit"
      check:
        readInput(db = db) == "exit"

  test "Reading a character from the user's input":
    checkpoint "Reading a lowercase character"
    check:
      readChar(inputChar = 'c', db = db) == "c"
    checkpoint "Reading a uppercase character"
    check:
      readChar(inputChar = 'H', db = db) == "H"

  test "Deleting a character":
    var
      inputString: UserInput = "my text"
      cursorPosition: Natural = 1
    deleteChar(inputString = inputString, cursorPosition = cursorPosition)
    check:
      inputString == "y text"
      cursorPosition == 0

  test "Moving the cursor":
    const inputString: UserInput = "my text"
    var cursorPosition: Natural = 1
    moveCursor(inputChar = 'D', cursorPosition = cursorPosition,
        inputString = inputString, db = db)
    check:
      cursorPosition == 0

  test "Updating the user's input":
    var
      inputString: UserInput = "my text"
      cursorPosition: Natural = 7
    updateInput(cursorPosition = cursorPosition, inputString = inputString,
        insertMode = false, inputRune = "a")
    check:
      inputString == "my texta"
      cursorPosition == 8

  test "Asking user for a name from the list":
    when not defined(testInput):
      skip()
    else:
      var color: Color = newColor()
      askForName[Color](db = db, action = "Testing", namesType = "color", name = color)
      echo color.description
      check:
        color != newColor()
