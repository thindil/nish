import std/[db_sqlite, tables]
import ../../../src/[constants, history, nish]

proc initTest*(): tuple[db: DbConn, historyIndex: HistoryRange] =
  let db = startDb("test.db")
  assert db != nil
  var helpContent = initTable[string, HelpEntry]()
  return (db, initHistory(db, helpContent))
