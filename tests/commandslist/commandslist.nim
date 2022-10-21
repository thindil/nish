discard """
  exitcode: 0
"""

import std/[db_sqlite, strutils, tables]
import ../../src/[commandslist, constants, directorypath, lstring, nish, resultcode]
import contracts

let db = startDb("test.db".DirectoryPath)
assert db != nil
if parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 0:
  if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
      "tests", "/", 1, "ls -a", "Test alias.") == -1:
    quit("Can't add test alias.", QuitFailure)
  if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
      "tests2", "/", 0, "ls -a", "Test alias 2.") == -1:
    quit("Can't add test2 alias.", QuitFailure)
var
  commands = newTable[string, CommandData]()

proc testCommand*(arguments: UserInput; db: DbConn;
    list: CommandLists): ResultCode {.gcsafe, raises: [], contractual.} =
  body:
    echo "test"

# Add a command
addCommand(name = initLimitedString(capacity = 4, text = "test"),
    command = testCommand, commands = commands)
assert commands.len() == 1
# Try to add again the same command
try:
  addCommand(name = initLimitedString(capacity = 4, text = "test"),
      command = testCommand, commands = commands)
except CommandsListError:
  discard
assert commands.len() == 1
# Try to replace built-in command
try:
  addCommand(name = initLimitedString(capacity = 4, text = "exit"),
      command = testCommand, commands = commands)
except CommandsListError:
  discard
assert commands.len() == 1

proc testCommand2(arguments: UserInput; db: DbConn;
    list: CommandLists): ResultCode {.gcsafe, raises: [], contractual.} =
  body:
    echo "test2"

# Replace command with new procedure
replaceCommand(name = initLimitedString(capacity = 4, text = "test"),
    command = testCommand2, commands = commands)
# Try to replace non existing command
try:
  replaceCommand(name = initLimitedString(capacity = 4, text = "exit"),
      command = testCommand, commands = commands)
except CommandsListError:
  discard

# Delete the command
deleteCommand(name = initLimitedString(capacity = 4, text = "test"),
    commands = commands)
assert commands.len() == 0
# Try to delete non-existing command
addCommand(name = initLimitedString(capacity = 5, text = "test2"),
    command = testCommand, commands = commands)
assert commands.len() == 1
try:
  deleteCommand(name = initLimitedString(capacity = 4, text = "test"),
      commands = commands)
except CommandsListError:
  discard
assert commands.len() == 1

quitShell(ResultCode(QuitSuccess), db)
