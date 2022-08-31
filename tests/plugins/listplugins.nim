discard """
  outputsub: plugins are
"""

import std/tables
import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var (db, _) = initTest()
var pluginsList: PluginsList = initTable[string, PluginData]()
assert setTestPlugin(db, pluginsList) == QuitSuccess
assert listPlugins(initLimitedString(capacity = 4, text = "list"), pluginsList, db) == QuitSuccess
assert listPlugins(initLimitedString(capacity = 8, text = "list all"), pluginsList, db) == QuitSuccess
assert listPlugins(initLimitedString(capacity = 8, text = "werwerew"), pluginsList, db) == QuitSuccess
quitShell(ResultCode(QuitSuccess), db)
