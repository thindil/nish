discard """
  exitcode: 0
"""

import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var
  (db, helpContent) = initTest()
  pluginsList = initPlugins(helpContent, db)
assert setTestPlugin(db, pluginsList) == QuitSuccess
assert removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
    pluginsList) == QuitSuccess
assert removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
    pluginsList) == QuitFailure
quitShell(QuitSuccess.ResultCode, db)
