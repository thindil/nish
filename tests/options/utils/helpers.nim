import std/[db_sqlite, tables]
import ../../../src/[constants, history, nish]

proc initTest*(): DbConn =
  result = startDb("test.db")
  assert result != nil
  var helpContent = initTable[string, HelpEntry]()
  discard initHistory(result, helpContent)
