discard """
  exitcode: 0
"""

import std/tables
import ../../src/[constants, help, nish]
import utils/helpers

var (db, helpContent) = initTest()
updateHelp(helpContent, db)
assert helpContent.len() == 1
quitShell(ResultCode(QuitSuccess), db)
