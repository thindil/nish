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
discard removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
    pluginsList, commands)
assert addPlugin(db, initLimitedString(capacity = 23,
    "add tools/testplugin.sh"), pluginsList, commands) == QuitSuccess
assert addPlugin(db, initLimitedString(capacity = 23,
    "add tools/testplugin.sh"), pluginsList, commands) == QuitFailure
assert addPlugin(db, initLimitedString(capacity = 26,
    "add tools/testplugin.223sh"), pluginsList, commands) == QuitFailure
quitShell(QuitSuccess.ResultCode, db)
