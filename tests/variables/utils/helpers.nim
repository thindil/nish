import std/[db_sqlite, tables]
import ../../../src/[constants, history, nish, variables]

proc initTest*(): tuple[db: DbConn, helpContent: HelpTable,
    historyIndex: HistoryRange] =
  let db = startDb("test.db")
  assert db != nil
  var helpContent = initTable[string, HelpEntry]()
  initVariables(helpContent, db)
  return (db, helpContent, initHistory(db, helpContent))
