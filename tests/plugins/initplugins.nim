discard """
  exitcode: 0
"""

import ../../src/[nish, lstring, plugins, resultcode]
import utils/helpers

var
  (db, helpContent, historyIndex) = initTest()
  pluginsList = initPlugins(helpContent, db)
discard removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
    pluginsList, historyIndex)
assert addPlugin(db, initLimitedString(capacity = 23,
    "add tools/testplugin.sh"), pluginsList) == QuitSuccess
quitShell(QuitSuccess.ResultCode, db)
