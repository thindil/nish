discard """
  exitcode: 0
"""

import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var (db, pluginsList, commands) = initTest()
initPlugins(db, pluginsList, commands)
discard removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
    pluginsList, commands)
assert addPlugin(db, initLimitedString(capacity = 23,
    "add tools/testplugin.sh"), pluginsList, commands) == QuitSuccess
assert addPlugin(db, initLimitedString(capacity = 23,
    "add tools/testplugin.sh"), pluginsList, commands) == QuitFailure
assert addPlugin(db, initLimitedString(capacity = 26,
    "add tools/testplugin.223sh"), pluginsList, commands) == QuitFailure
quitShell(QuitSuccess.ResultCode, db)
