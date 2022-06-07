discard """
  exitcode: 0
"""

import ../../src/[constants, commands, nish, resultcode]
import utils/helpers

var (db, myaliases) = initTest()
assert cdCommand("/".DirectoryPath, myaliases, db) == QuitSuccess
assert cdCommand("/adfwerewtr".DirectoryPath, myaliases, db) == QuitFailure
quitShell(ResultCode(QuitSuccess), db)
