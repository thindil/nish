import utils/utils
import ../src/db
import unittest2
include ../src/highlight

suite "Unit tests for highlight module":

  checkpoint "Initializing the tests"
  let db: DbConn = initDb(dbName = "test7.db")
  var
    myaliases: ref OrderedTable[string, int] = newOrderedTable[string, int]()
    commands: ref Table[string, CommandData] = newTable[string, CommandData]()
    inputString: UserInput = "test"

  test "Highlighting the shell's output":
    highlightOutput(promptLength = 0, inputString = inputString,
        commands = commands, aliases = myaliases, oneTimeCommand = false,
        commandName = "", returnCode = QuitSuccess.ResultCode, db = db,
        cursorPosition = 0, enabled = true)

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
