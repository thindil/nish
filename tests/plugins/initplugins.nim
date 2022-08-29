discard """
  exitcode: 0
"""

import ../../src/[nish, plugins, resultcode]
import utils/helpers

var
  (db, helpContent, _) = initTest()
  pluginsList = initPlugins(helpContent, db)
assert setTestPlugin(db, pluginsList) == QuitSuccess
quitShell(QuitSuccess.ResultCode, db)
