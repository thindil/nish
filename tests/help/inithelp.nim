discard """
  exitcode: 0
"""

import std/tables
import ../../src/[commandslist, help, nish, resultcode]
import utils/helpers

var
  (db, helpContent) = initTest()
  commands: CommandsList = initTable[string, CommandProc]()
initHelp(helpContent, db, commands)
assert commands.len() == 1
quitShell(ResultCode(QuitSuccess), db)
