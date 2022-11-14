discard """
  exitcode: 0
"""

import std/[db_sqlite, os, strutils, tables]
import ../../src/[aliases, directorypath, commandslist, lstring, nish, resultcode]
import contracts

let db = startDb("test.db".DirectoryPath)
assert db != nil, "No connection to database."
var
  myaliases = newOrderedTable[LimitedString, int]()
  commands = newTable[string, CommandData]()

if parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 0:
  if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
      "tests", "/", 1, "ls -a", "Test alias.") == -1:
    quit("Can't add test alias.")
if parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 1:
  if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
      "tests2", "/", 0, "ls -a", "Test alias 2.") == -1:
    quit("Can't add the second test alias.")

initAliases(db, myaliases, commands)
assert myaliases.len() == 1, "Failed to set aliases for current directory."


assert deleteAlias(initLimitedString(capacity = 8, text = "delete 2"),
    myaliases, db) == QuitSuccess, "Failed to delete an alias."
assert parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 1
assert deleteAlias(initLimitedString(capacity = 9, text = "delete 22"),
    myaliases, db) == QuitFailure, "Failed to not delete a non-existing alias."
if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
    "tests2", "/", 0, "ls -a", "Test alias 2.") == -1:
  quit("Can't add test2 alias.")
assert parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 2, "Failed to re-add an alias."

myaliases.setAliases(getCurrentDir().DirectoryPath, db)
assert execAlias(emptyLimitedString(), "tests", myaliases, db) == QuitSuccess, "Failed to execute an alias."
assert execAlias(emptyLimitedString(), "tests2", myaliases, db) == QuitFailure, "Failed to not execute a noon-existing alias."

assert parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 2
assert listAliases(initLimitedString(capacity = 4, text = "list"), myaliases,
    db) == QuitSuccess, "Failed to show the list of available aliases."
assert listAliases(initLimitedString(capacity = 8, text = "list all"),
    myaliases, db) == QuitSuccess, "Failed to show the list of all aliases."
try:
  assert listAliases(initLimitedString(capacity = 8, text = "werwerew"),
      myaliases, db) == QuitSuccess
except PreConditionDefect:
  discard

quitShell(ResultCode(QuitSuccess), db)
