discard """
  exitcode: 0
"""

import std/tables
import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var (db, _, historyIndex) = initTest()
var pluginsList: PluginsList = initTable[string, PluginData]()
assert setTestPlugin(db, pluginsList, historyIndex) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 9, "disable 1"),
    pluginsList, historyIndex) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 8, "enable 1"),
    pluginsList, historyIndex, false) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 8, "enable 2"),
    pluginsList, historyIndex, false) == QuitFailure
quitShell(QuitSuccess.ResultCode, db)
