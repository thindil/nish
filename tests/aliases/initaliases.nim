discard """
  exitcode: 0
"""

import std/tables
import ../../src/[aliases, commandslist, nish, resultcode]
import utils/helpers

var
  (db, helpContent, myaliases) = initTest()
  commands: CommandsList = initTable[string, CommandData]()
assert setTestAliases(db) == QuitSuccess
initAliases(helpContent, db, myaliases, commands)
assert myaliases.len() == 1
assert helpContent.len() == 6
quitShell(ResultCode(QuitSuccess), db)
