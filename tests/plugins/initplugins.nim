discard """
  exitcode: 0
"""

import ../../src/[nish, plugins, resultcode]
import utils/helpers

var
  (db, helpContent, historyIndex) = initTest()
  pluginsList = initPlugins(helpContent, db)
assert setTestPlugin(db, pluginsList, historyIndex) == QuitSuccess
quitShell(QuitSuccess.ResultCode, db)
