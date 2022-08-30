discard """
  exitcode: 0
"""

import std/tables
import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var (db, _, _) = initTest()
var pluginsList: PluginsList = initTable[string, PluginData]()
assert setTestPlugin(db, pluginsList) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 9, "disable 1"),
    pluginsList) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 8, "enable 1"),
    pluginsList, false) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 8, "enable 2"),
    pluginsList, false) == QuitFailure
quitShell(QuitSuccess.ResultCode, db)
