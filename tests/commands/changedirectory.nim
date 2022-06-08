discard """
  exitcode: 0
"""

import ../../src/[commands, directorypath, nish, resultcode]
import utils/helpers

var (db, myaliases) = initTest()
assert changeDirectory("..".DirectoryPath, myaliases, db) == QuitSuccess
assert changeDirectory("/adfwerewtr".DirectoryPath, myaliases, db) == QuitFailure
quitShell(ResultCode(QuitSuccess), db)
