discard """
  exitcode: 0
"""

import std/[db_sqlite, os, strutils, tables]
import ../../src/[commandslist, directorypath, lstring, nish, resultcode, variables]

assert buildQuery("/".DirectoryPath, "name") == "SELECT name FROM variables WHERE path='/' ORDER BY id ASC"

let db = startDb("test.db".DirectoryPath)
assert db != nil
var commands = newTable[string, CommandData]()

initVariables(db, commands)

if parseInt(db.getValue(sql"SELECT COUNT(*) FROM variables")) == 0:
  if db.tryInsertID(sql"INSERT INTO variables (name, path, recursive, value, description) VALUES (?, ?, ?, ?, ?)",
      "TESTS", "/", 1, "test_variable", "Test variable.") == -1:
    quit QuitFailure
  if db.tryInsertID(sql"INSERT INTO variables (name, path, recursive, value, description) VALUES (?, ?, ?, ?, ?)",
      "TESTS2", "/", 0, "test_variable2", "Test variable 2.") == -1:
    quit QuitFailure
if parseInt(db.getValue(sql"SELECT COUNT(*) FROM variables")) == 1:
  if db.tryInsertID(sql"INSERT INTO variables (name, path, recursive, value, description) VALUES (?, ?, ?, ?, ?)",
      "TESTS2", "/", 0, "test_variable2", "Test variable 2.") == -1:
    quit QuitFailure

setVariables("/home".DirectoryPath, db)
assert getEnv("TESTS") == "test_variable"
assert not existsEnv("TESTS2")

assert listVariables(initLimitedString(capacity = 4, text = "list"), db) == QuitSuccess
assert listVariables(initLimitedString(capacity = 8, text = "list all"), db) == QuitSuccess
assert listVariables(initLimitedString(capacity = 8, text = "werwerew"), db) == QuitSuccess

assert deleteVariable(initLimitedString(capacity = 10, text = "delete 123"),
    db) == QuitFailure
assert deleteVariable(initLimitedString(capacity = 10, text = "delete sdf"),
    db) == QuitFailure
assert deleteVariable(initLimitedString(capacity = 8, text = "delete 2"), db) == QuitSuccess
assert deleteVariable(initLimitedString(capacity = 8, text = "delete 2"), db) == QuitFailure

assert setCommand(initLimitedString(capacity = 13, text = "test=test_val")) == QuitSuccess
assert getEnv("test") == "test_val"

assert unsetCommand(initLimitedString(capacity = 4, text = "test")) == QuitSuccess
assert getEnv("test") == ""
assert unsetCommand(initLimitedString(capacity = 4, text = "test")) == QuitSuccess

quitShell(ResultCode(QuitSuccess), db)

