import std/[db_sqlite, tables]
import ../../../src/[constants, directorypath, history, nish]

proc initTest*(): tuple[db: DbConn, helpContent: HelpTable,
    historyIndex: HistoryRange] =
  let db = startDb("test.db".DirectoryPath)
  assert db != nil
  var helpContent = initTable[string, HelpEntry]()
  return (db, helpContent, initHistory(db, helpContent))
