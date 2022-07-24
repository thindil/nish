import std/[db_sqlite, tables]
import ../../../src/[constants, directorypath, lstring, history, nish, plugins, resultcode]

proc initTest*(): tuple[db: DbConn, helpContent: HelpTable,
    historyIndex: HistoryRange] =
  let db = startDb("test.db".DirectoryPath)
  assert db != nil
  var helpContent = initTable[string, HelpEntry]()
  return (db, helpContent, initHistory(db, helpContent))

proc setTestPlugin*(db: DbConn; pluginsList: var PluginsList;
    historyIndex: var HistoryRange): ResultCode =
  discard removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
      pluginsList, historyIndex)
  return addPlugin(db, initLimitedString(capacity = 23,
      "add tools/testplugin.sh"), pluginsList)
