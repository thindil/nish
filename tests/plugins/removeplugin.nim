discard """
  exitcode: 0
"""

import std/tables
import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var (db, _, historyIndex) = initTest()
var pluginsList: PluginsList = initTable[string, string]()
assert setTestPlugin(db, pluginsList, historyIndex) == QuitSuccess
assert removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
    pluginsList, historyIndex) == QuitSuccess
assert removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
    pluginsList, historyIndex) == QuitFailure
quitShell(QuitSuccess.ResultCode, db)
