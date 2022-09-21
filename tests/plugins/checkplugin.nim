discard """
  exitcode: 0
"""

import std/tables
import ../../src/[commandslist, nish, plugins, resultcode]
import utils/helpers

var
  (db, _) = initTest()
  commands = newTable[string, CommandData]()
assert checkPlugin("tools/testplugin.sh", db, commands).path == "tools/testplugin.sh"
assert checkPlugin("sdfsdfds.df", db, commands).path.len() == 0
quitShell(QuitSuccess.ResultCode, db)
