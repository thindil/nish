discard """
  exitcode: 0
"""

import std/tables
import ../../src/[commandslist, nish, variables, resultcode]
import utils/helpers

var
  db = initTest()
  commands = newTable[string, CommandData]()
initVariables(db, commands)
quitShell(ResultCode(QuitSuccess), db)
