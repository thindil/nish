import std/[db_sqlite, strutils, tables]
import ../../../src/[aliases, constants, directorypath, lstring, nish]

proc initTest*(): tuple[db: DbConn, helpContent: ref HelpTable, aliases: AliasesList] =
  let db = startDb("test.db".DirectoryPath)
  assert db != nil
  var helpContent = newTable[string, HelpEntry]()
  return (db, helpContent, newOrderedTable[LimitedString, int]())

proc setTestAliases*(db: DbConn): int =
  if parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 0:
    if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
        "tests", "/", 1, "ls -a", "Test alias.") == -1:
      return QuitFailure
  if parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 1:
    if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
        "tests2", "/", 0, "ls -a", "Test alias 2.") == -1:
      return QuitFailure
