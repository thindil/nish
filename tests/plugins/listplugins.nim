discard """
  outputsub: plugins are
"""

import std/tables
import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var (db, _, historyIndex) = initTest()
var pluginsList: PluginsList = initTable[string, PluginData]()
assert setTestPlugin(db, pluginsList) == QuitSuccess
listPlugins(initLimitedString(capacity = 4, text = "list"), historyIndex,
    pluginsList, db)
listPlugins(initLimitedString(capacity = 8, text = "list all"), historyIndex,
    pluginsList, db)
listPlugins(initLimitedString(capacity = 8, text = "werwerew"), historyIndex,
    pluginsList, db)
quitShell(ResultCode(QuitSuccess), db)
