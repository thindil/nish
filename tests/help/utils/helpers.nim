import std/[db_sqlite, tables]
import ../../../src/[constants, directorypath, nish]

proc initTest*(): tuple[db: DbConn, helpContent: ref HelpTable] =
  let db = startDb("test.db".DirectoryPath)
  assert db != nil
  return (db, newTable[string, HelpEntry]())
