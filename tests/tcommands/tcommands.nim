discard """
  exitcode: 0
  outputsub: "/adfwerewtr"
"""

import std/[strutils, tables]
when (NimMajor, NimMinor, NimPatch) >= (1, 7, 3):
  import db_connector/db_sqlite
else:
  import std/db_sqlite
import ../../src/[commands, directorypath, lstring, nish, resultcode]

block:
  let db = startDb("test3.db".DirectoryPath)
  assert db != nil, "Failed to initialize database."
  if parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 0:
    if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
        "tests", "/", 1, "ls -a", "Test alias.") == -1:
      quit("Can't add test alias.", QuitFailure)
    if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
        "tests2", "/", 0, "ls -a", "Test alias 2.") == -1:
      quit("Can't add test2 alias.", QuitFailure)
  var myaliases = newOrderedTable[LimitedString, int]()

  assert cdCommand("/".DirectoryPath, myaliases, db) == QuitSuccess, "Failed to enter an existing directory."
  assert cdCommand("/adfwerewtr".DirectoryPath, myaliases, db) == QuitFailure, "Failed to not enter a non-existing directory."

  assert changeDirectory("..".DirectoryPath, myaliases, db) == QuitSuccess, "Failed to change the working directory."
  assert changeDirectory("/adfwerewtr".DirectoryPath, myaliases, db) ==
      QuitFailure, "Failed to not change the working directory."

  quitShell(ResultCode(QuitSuccess), db)
