discard """
  exitcode: 0
"""

import std/tables
import ../../src/[directorypath, commandslist, highlight, lstring, nish, resultcode, constants]

let db = startDb("test.db".DirectoryPath)
assert db != nil
var
  myaliases = newOrderedTable[LimitedString, int]()
  commands = newTable[string, CommandData]()
  inputString: UserInput = initLimitedString(4, "test")

highlightOutput(0, inputString, commands, myaliases, false, "", QuitSuccess.ResultCode, db, 0)

