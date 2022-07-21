discard """
  exitcode: 0
"""

import ../../src/[nish, plugins, resultcode]
import utils/helpers

let (db, _, _) = initTest()
assert execPlugin("tools/testplugin.sh", ["init"], db) == QuitSuccess
quitShell(QuitSuccess.ResultCode, db)
