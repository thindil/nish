discard """
  exitcode: 0
"""

import std/tables
import ../../src/[commandslist, constants, nish, plugins, resultcode]
import utils/helpers

var
  (db, helpContent) = initTest()
  pluginsList = newTable[string, PluginData]()
  commands = newTable[string, CommandData]()
initPlugins(helpContent, db, pluginsList, commands)
assert setTestPlugin(db, pluginsList) == QuitSuccess
quitShell(QuitSuccess.ResultCode, db)
