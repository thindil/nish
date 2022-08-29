discard """
  exitcode: 0
"""

import std/tables
import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var (db, _, _) = initTest()
var pluginsList: PluginsList = initTable[string, PluginData]()
assert setTestPlugin(db, pluginsList) == QuitSuccess
assert removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
    pluginsList) == QuitSuccess
assert removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
    pluginsList) == QuitFailure
quitShell(QuitSuccess.ResultCode, db)
