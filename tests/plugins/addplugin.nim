discard """
  exitcode: 0
"""

import std/tables
import ../../src/[commandslist, constants, lstring, nish, plugins, resultcode]
import utils/helpers

var
  (db, helpContent) = initTest()
  pluginsList = newTable[string, PluginData]()
  commands = newTable[string, CommandData]()
initPlugins(helpContent, db, pluginsList, commands)
discard removePlugin(db, initLimitedString(capacity = 8, "remove 1"), pluginsList)
assert addPlugin(db, initLimitedString(capacity = 23,
    "add tools/testplugin.sh"), pluginsList) == QuitSuccess
assert addPlugin(db, initLimitedString(capacity = 23,
    "add tools/testplugin.sh"), pluginsList) == QuitFailure
assert addPlugin(db, initLimitedString(capacity = 26,
    "add tools/testplugin.223sh"), pluginsList) == QuitFailure
quitShell(QuitSuccess.ResultCode, db)
