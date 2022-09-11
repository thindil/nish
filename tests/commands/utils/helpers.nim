import std/[db_sqlite, strutils, tables]
import ../../../src/[constants, directorypath, lstring, nish]

proc initTest*(): tuple[db: DbConn, aliases: ref AliasesList] =
  let db = startDb("test.db".DirectoryPath)
  assert db != nil
  if parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 0:
    if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
        "tests", "/", 1, "ls -a", "Test alias.") == -1:
      quit("Can't add test alias.", QuitFailure)
    if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
        "tests2", "/", 0, "ls -a", "Test alias 2.") == -1:
      quit("Can't add test2 alias.", QuitFailure)
  var aliases = newOrderedTable[LimitedString, int]()
  return (db, aliases)
