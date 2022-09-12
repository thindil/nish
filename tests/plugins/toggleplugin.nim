discard """
  exitcode: 0
"""

import std/tables
import ../../src/[commandslist, constants, lstring, nish, plugins, resultcode]
import utils/helpers

var
  (db, helpContent) = initTest()
  pluginsList = newTable[string, PluginData]()
  commands: CommandsList = initTable[string, CommandProc]()
initPlugins(helpContent, db, pluginsList, commands)
assert setTestPlugin(db, pluginsList) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 9, "disable 1"),
    pluginsList) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 8, "enable 1"),
    pluginsList, false) == QuitSuccess
assert togglePlugin(db, initLimitedString(capacity = 8, "enable 2"),
    pluginsList, false) == QuitFailure
quitShell(QuitSuccess.ResultCode, db)
