discard """
  exitcode: 0
"""

import ../../src/[constants, help, nish]
import utils/helpers

var (db, helpContent) = initTest()
updateHelp(helpContent, db)
assert showHelp("history show", helpContent, db) == QuitSuccess
assert showHelp("srewfdsfs", helpContent, db) == QuitFailure
quitShell(ResultCode(QuitSuccess), db)
