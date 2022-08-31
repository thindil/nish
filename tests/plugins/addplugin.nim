discard """
  exitcode: 0
"""

import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var
  (db, helpContent) = initTest()
  pluginsList = initPlugins(helpContent, db)
discard removePlugin(db, initLimitedString(capacity = 8, "remove 1"), pluginsList)
assert addPlugin(db, initLimitedString(capacity = 23,
    "add tools/testplugin.sh"), pluginsList) == QuitSuccess
assert addPlugin(db, initLimitedString(capacity = 23,
    "add tools/testplugin.sh"), pluginsList) == QuitFailure
assert addPlugin(db, initLimitedString(capacity = 26,
    "add tools/testplugin.223sh"), pluginsList) == QuitFailure
quitShell(QuitSuccess.ResultCode, db)
