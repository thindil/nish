discard """
  exitcode: 0
"""

import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var (db, commands) = initTest()
initPlugins(db, commands)
assert setTestPlugin(db, commands) == QuitSuccess
assert removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
    commands) == QuitSuccess
assert removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
    commands) == QuitFailure
quitShell(QuitSuccess.ResultCode, db)
