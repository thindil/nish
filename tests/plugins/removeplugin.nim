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
assert setTestPlugin(db, pluginsList, commands) == QuitSuccess
assert removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
    pluginsList, commands) == QuitSuccess
assert removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
    pluginsList, commands) == QuitFailure
quitShell(QuitSuccess.ResultCode, db)
