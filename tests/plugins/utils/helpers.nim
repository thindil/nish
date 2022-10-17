import std/[db_sqlite, tables]
import ../../../src/[commandslist, directorypath, lstring, nish, plugins, resultcode]

proc initTest*(): tuple[db: DbConn, commands: ref CommandsList] =
  let db = startDb("test.db".DirectoryPath)
  assert db != nil
  var commands = newTable[string, CommandData]()
  return (db, commands)

proc setTestPlugin*(db: DbConn; commands: ref CommandsList): ResultCode =
  discard removePlugin(db, initLimitedString(capacity = 8, "remove 1"), commands)
  return addPlugin(db, initLimitedString(capacity = 23,
      "add tools/testplugin.sh"), commands)
