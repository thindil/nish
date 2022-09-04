import std/[db_sqlite, tables]
import ../../../src/[constants, directorypath, lstring, nish, plugins, resultcode]

proc initTest*(): tuple[db: DbConn, helpContent: ref HelpTable] =
  let db = startDb("test.db".DirectoryPath)
  assert db != nil
  var helpContent = newTable[string, HelpEntry]()
  return (db, helpContent)

proc setTestPlugin*(db: DbConn; pluginsList: var PluginsList): ResultCode =
  discard removePlugin(db, initLimitedString(capacity = 8, "remove 1"), pluginsList)
  return addPlugin(db, initLimitedString(capacity = 23,
      "add tools/testplugin.sh"), pluginsList)
