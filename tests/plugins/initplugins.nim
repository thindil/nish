discard """
  exitcode: 0
"""

import ../../src/[nish, plugins, resultcode]
import utils/helpers

var (db, pluginsList, commands) = initTest()
initPlugins(db, pluginsList, commands)
assert setTestPlugin(db, pluginsList, commands) == QuitSuccess
quitShell(QuitSuccess.ResultCode, db)
