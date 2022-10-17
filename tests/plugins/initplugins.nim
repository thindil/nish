discard """
  exitcode: 0
"""

import ../../src/[nish, plugins, resultcode]
import utils/helpers

var (db, commands) = initTest()
initPlugins(db, commands)
assert setTestPlugin(db, commands) == QuitSuccess
quitShell(QuitSuccess.ResultCode, db)
