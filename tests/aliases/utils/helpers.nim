import std/[db_sqlite, tables]
import ../../../src/[aliases, constants, history, nish]

proc initTest*(): tuple[db: DbConn, helpContent: HelpTable,
    historyIndex: HistoryRange, aliases: AliasesList] =
  let db = startDb("test.db")
  assert db != nil
  var helpContent = initTable[string, HelpEntry]()
  return (db, helpContent, initHistory(db, helpContent), initOrderedTable[
      string, int]())
