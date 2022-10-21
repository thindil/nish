discard """
  exitcode: 0
"""

import std/[db_sqlite, strutils, tables]
import ../../src/[commands, directorypath, lstring, nish, resultcode]

let db = startDb("test.db".DirectoryPath)
assert db != nil
if parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 0:
  if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
      "tests", "/", 1, "ls -a", "Test alias.") == -1:
    quit("Can't add test alias.", QuitFailure)
  if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
      "tests2", "/", 0, "ls -a", "Test alias 2.") == -1:
    quit("Can't add test2 alias.", QuitFailure)
var myaliases = newOrderedTable[LimitedString, int]()

assert cdCommand("/".DirectoryPath, myaliases, db) == QuitSuccess
assert cdCommand("/adfwerewtr".DirectoryPath, myaliases, db) == QuitFailure

assert changeDirectory("..".DirectoryPath, myaliases, db) == QuitSuccess
assert changeDirectory("/adfwerewtr".DirectoryPath, myaliases, db) == QuitFailure

quitShell(ResultCode(QuitSuccess), db)
