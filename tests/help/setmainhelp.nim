discard """
  exitcode: 0
"""

import std/tables
import ../../src/[help, nish, resultcode]
import utils/helpers

var (db, helpContent) = initTest()
updateHelp(helpContent, db)
setMainHelp(helpContent)
assert helpContent.len() == 2
quitShell(ResultCode(QuitSuccess), db)
