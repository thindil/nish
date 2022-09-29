discard """
  exitcode: 0
"""

import std/tables
import ../../src/[aliases, commandslist, nish, resultcode]
import utils/helpers

var
  (db, myaliases) = initTest()
  commands = newTable[string, CommandData]()
assert setTestAliases(db) == QuitSuccess
initAliases(db, myaliases, commands)
assert myaliases.len() == 1
quitShell(ResultCode(QuitSuccess), db)
