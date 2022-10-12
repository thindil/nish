discard """
  exitcode: 0
"""

import std/tables
import ../../src/[commandslist, help, nish, resultcode]
import utils/helpers

var
  db = initTest()
  commands = newTable[string, CommandData]()
initHelp(db, commands)
assert commands.len() == 2
quitShell(ResultCode(QuitSuccess), db)
