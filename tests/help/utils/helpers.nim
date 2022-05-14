import std/[db_sqlite, tables]
import ../../../src/[constants, nish]

proc initTest*(): tuple[db: DbConn, helpContent: HelpTable] =
  let db = startDb("test.db")
  assert db != nil
  return (db, initTable[string, HelpEntry]())
