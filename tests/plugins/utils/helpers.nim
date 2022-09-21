import std/[db_sqlite, tables]
import ../../../src/[commandslist, constants, directorypath, lstring, nish,
    plugins, resultcode]

proc initTest*(): tuple[db: DbConn, helpContent: ref HelpTable, pluginsList: ref PluginsList, commands: ref CommandsList] =
  let db = startDb("test.db".DirectoryPath)
  assert db != nil
  var
    helpContent = newTable[string, HelpEntry]()
    pluginsList = newTable[string, PluginData]()
    commands = newTable[string, CommandData]()
  return (db, helpContent, pluginsList, commands)

proc setTestPlugin*(db: DbConn; pluginsList: ref PluginsList;
    commands: ref CommandsList): ResultCode =
  discard removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
      pluginsList, commands)
  return addPlugin(db, initLimitedString(capacity = 23,
      "add tools/testplugin.sh"), pluginsList, commands)
