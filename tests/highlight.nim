import std/tables
import ../src/[db, directorypath, commandslist, highlight, lstring,
    resultcode, constants]
import unittest2

suite "Unit tests for highlight module":

  let db = startDb("test7.db".DirectoryPath)
  assert db != nil, "Failed to initialize the database"
  var
    myaliases = newOrderedTable[LimitedString, int]()
    commands = newTable[string, CommandData]()
    inputString: UserInput = initLimitedString(4, "test")

  test "hightlighOutput":
    highlightOutput(0, inputString, commands, myaliases, false, "",
        QuitSuccess.ResultCode, db, 0, true)

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
