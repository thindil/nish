import std/[db_sqlite, tables]
import ../../../src/[commandslist, directorypath, history, nish]

proc initTest*(): DbConn =
  result = startDb("test.db".DirectoryPath)
  assert result != nil
  var commands = newTable[string, CommandData]()
  discard initHistory(result, commands)
