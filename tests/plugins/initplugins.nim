discard """
  exitcode: 0
"""

import ../../src/[nish, plugins, resultcode]
import utils/helpers

var (db, helpContent, pluginsList, commands) = initTest()
initPlugins(helpContent, db, pluginsList, commands)
assert setTestPlugin(db, pluginsList, commands) == QuitSuccess
quitShell(QuitSuccess.ResultCode, db)
