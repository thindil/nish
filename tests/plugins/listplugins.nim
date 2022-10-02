discard """
  outputsub: plugins are
"""

import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var (db, pluginsList, commands) = initTest()
initPlugins(db, pluginsList, commands)
assert setTestPlugin(db, pluginsList, commands) == QuitSuccess
assert listPlugins(initLimitedString(capacity = 4, text = "list"), pluginsList, db) == QuitSuccess
assert listPlugins(initLimitedString(capacity = 8, text = "list all"), pluginsList, db) == QuitSuccess
assert listPlugins(initLimitedString(capacity = 8, text = "werwerew"), pluginsList, db) == QuitSuccess
quitShell(ResultCode(QuitSuccess), db)
