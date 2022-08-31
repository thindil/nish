discard """
  exitcode: 0
"""

import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var
  (db, helpContent) = initTest()
  pluginsList = initPlugins(helpContent, db)
assert setTestPlugin(db, pluginsList) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 9, "disable 1"),
    pluginsList) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 8, "enable 1"),
    pluginsList, false) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 8, "enable 2"),
    pluginsList, false) == QuitFailure
quitShell(QuitSuccess.ResultCode, db)
