discard """
  exitcode: 0
"""

import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var (db, pluginsList, commands) = initTest()
initPlugins(db, pluginsList, commands)
assert setTestPlugin(db, pluginsList, commands) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 9, "disable 1"),
    pluginsList, true, commands) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 8, "enable 1"),
    pluginsList, false, commands) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 8, "enable 2"),
    pluginsList, false, commands) == QuitFailure
quitShell(QuitSuccess.ResultCode, db)
