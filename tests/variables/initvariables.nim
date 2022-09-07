discard """
  exitcode: 0
"""

import std/tables
import ../../src/[commandslist, nish, variables, resultcode]
import utils/helpers

var
  (db, helpContent) = initTest()
  commands: CommandsList = initTable[string, CommandProc]()
initVariables(helpContent, db, commands)
quitShell(ResultCode(QuitSuccess), db)
