import std/[db_sqlite, strutils, tables]
import ../../../src/[commandslist, constants, directorypath, nish, variables]

proc initTest*(): tuple[db: DbConn, helpContent: ref HelpTable] =
  let db = startDb("test.db".DirectoryPath)
  assert db != nil
  var
    helpContent = newTable[string, HelpEntry]()
    commands: CommandsList = initTable[string, CommandProc]()
  initVariables(helpContent, db, commands)
  return (db, helpContent)

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
