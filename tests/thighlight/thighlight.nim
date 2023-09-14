discard """
  exitcode: 0
  outputsub: test
"""

import std/tables
import ../../src/[directorypath, commandslist, highlight, lstring, nish,
    resultcode, constants]

block:
  let db = startDb("test7.db".DirectoryPath)
  assert db != nil, "Failed to initialize the database"
  var
    myaliases = newOrderedTable[LimitedString, int]()
    commands = newTable[string, CommandData]()
    inputString: UserInput = initLimitedString(4, "test")

  highlightOutput(0, inputString, commands, myaliases, false, "",
      QuitSuccess.ResultCode, db, 0, true)

  quitShell(ResultCode(QuitSuccess), db)
