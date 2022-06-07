discard """
  exitcode: 0
"""

import std/tables
import ../../src/[help, nish, resultcode]
import utils/helpers

var (db, helpContent) = initTest()
updateHelp(helpContent, db)
assert helpContent.len() == 1
quitShell(ResultCode(QuitSuccess), db)
