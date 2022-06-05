import std/[db_sqlite, strutils, tables]
import ../../../src/[constants, history, nish, variables]

proc initTest*(): tuple[db: DbConn, helpContent: HelpTable,
    historyIndex: HistoryRange] =
  let db = startDb("test.db".DirectoryPath)
  assert db != nil
  var helpContent = initTable[string, HelpEntry]()
  initVariables(helpContent, db)
  return (db, helpContent, initHistory(db, helpContent))

proc setTestVariables*(db: DbConn): int =
  if parseInt(db.getValue(sql"SELECT COUNT(*) FROM variables")) == 0:
      if db.tryInsertID(sql"INSERT INTO variables (name, path, recursive, value, description) VALUES (?, ?, ?, ?, ?)",
          "TESTS", "/", 1, "test_variable", "Test variable.") == -1:
        return QuitFailure
      if db.tryInsertID(sql"INSERT INTO variables (name, path, recursive, value, description) VALUES (?, ?, ?, ?, ?)",
          "TESTS2", "/", 0, "test_variable2", "Test variable 2.") == -1:
        return QuitFailure
  if parseInt(db.getValue(sql"SELECT COUNT(*) FROM variables")) == 1:
      if db.tryInsertID(sql"INSERT INTO variables (name, path, recursive, value, description) VALUES (?, ?, ?, ?, ?)",
          "TESTS2", "/", 0, "test_variable2", "Test variable 2.") == -1:
        return QuitFailure
  return QuitSuccess
