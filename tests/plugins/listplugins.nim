discard """
  outputsub: plugins are
"""

import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var
  (db, helpContent) = initTest()
  pluginsList = initPlugins(helpContent, db)
assert setTestPlugin(db, pluginsList) == QuitSuccess
assert listPlugins(initLimitedString(capacity = 4, text = "list"), pluginsList, db) == QuitSuccess
assert listPlugins(initLimitedString(capacity = 8, text = "list all"), pluginsList, db) == QuitSuccess
assert listPlugins(initLimitedString(capacity = 8, text = "werwerew"), pluginsList, db) == QuitSuccess
quitShell(ResultCode(QuitSuccess), db)
