discard """
  exitcode: 0
"""

import std/tables
import ../../src/[commandslist, nish, lstring, plugins, resultcode]
import utils/helpers

let (db, _) = initTest()
var commands = newTable[string, CommandData]()
assert execPlugin("tools/testplugin.sh", ["init"], db, commands).code == QuitSuccess
assert execPlugin("tools/testplugin.sh", ["info"], db, commands).answer.len() > 0
quitShell(QuitSuccess.ResultCode, db)
