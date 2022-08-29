discard """
  exitcode: 0
"""

import std/tables
import ../../src/[lstring, nish, plugins, resultcode]
import utils/helpers

var (db, _, _) = initTest()
var pluginsList: PluginsList = initTable[string, PluginData]()
discard removePlugin(db, initLimitedString(capacity = 8, "remove 1"), pluginsList)
assert addPlugin(db, initLimitedString(capacity = 23,
    "add tools/testplugin.sh"), pluginsList) == QuitSuccess
assert addPlugin(db, initLimitedString(capacity = 23,
    "add tools/testplugin.sh"), pluginsList) == QuitFailure
assert addPlugin(db, initLimitedString(capacity = 26,
    "add tools/testplugin.223sh"), pluginsList) == QuitFailure
quitShell(QuitSuccess.ResultCode, db)
