discard """
  exitcode: 0
"""

import ../../src/[nish, lstring, plugins, resultcode]
import utils/helpers

var (db, commands) = initTest()
assert execPlugin("tools/testplugin.sh", ["init"], db, commands).code == QuitSuccess
assert execPlugin("tools/testplugin.sh", ["info"], db, commands).answer.len() > 0
quitShell(QuitSuccess.ResultCode, db)
