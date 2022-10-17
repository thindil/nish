discard """
  exitcode: 0
"""

import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var (db, commands) = initTest()
initPlugins(db, commands)
discard removePlugin(db, initLimitedString(capacity = 8, "remove 1"), commands)
assert addPlugin(db, initLimitedString(capacity = 23,
    "add tools/testplugin.sh"), commands) == QuitSuccess
assert addPlugin(db, initLimitedString(capacity = 23,
    "add tools/testplugin.sh"), commands) == QuitFailure
assert addPlugin(db, initLimitedString(capacity = 26,
    "add tools/testplugin.223sh"), commands) == QuitFailure
quitShell(QuitSuccess.ResultCode, db)
