import std/[db_sqlite, tables]
import ../../../src/[constants, directorypath, history, nish]

proc initTest*(): DbConn =
  result = startDb("test.db".DirectoryPath)
  assert result != nil
  var helpContent = initTable[string, HelpEntry]()
  discard initHistory(result, helpContent)
