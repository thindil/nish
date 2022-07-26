discard """
  exitcode: 0
"""

import ../../src/[nish, lstring, plugins, resultcode]
import utils/helpers

let (db, _, _) = initTest()
assert execPlugin("tools/testplugin.sh", ["init"], db).code == QuitSuccess
assert execPlugin("tools/testplugin.sh", ["info"], db).answer.len() > 0
quitShell(QuitSuccess.ResultCode, db)
