import std/[db_sqlite, tables]
import ../../../src/[commandslist, directorypath, history, nish]

proc initTest*(): tuple[db: DbConn, historyIndex: HistoryRange] =
  let db = startDb("test.db".DirectoryPath)
  assert db != nil
  var commands = newTable[string, CommandData]()
  return (db, initHistory(db, commands))

proc setTestHistory*(db: DbConn): int =
  if db.tryInsertID(sql"INSERT INTO history (command, amount, lastused) VALUES (?, 1, datetime('now'))",
      "alias delete") == -1:
    return QuitFailure
  return QuitSuccess
