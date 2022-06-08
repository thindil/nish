import std/[db_sqlite, tables]
import ../../../src/[constants, directorypath, nish]

proc initTest*(): tuple[db: DbConn, helpContent: HelpTable] =
  let db = startDb("test.db".DirectoryPath)
  assert db != nil
  return (db, initTable[string, HelpEntry]())
