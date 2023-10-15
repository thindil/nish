discard """
  exitcode: 0
"""

import std/[strutils, tables]
import ../../src/[aliases, commandslist, constants, db, directorypath, lstring, resultcode]
import contracts
import norm/sqlite

block:
  let db = startDb("test4.db".DirectoryPath)
  assert db != nil, "Failed to initialized database."
  if db.count(Alias) == 0:
    try:
      var alias = newAlias(name = "tests", path = "/", recursive = true,
          commands = "ls -a", description = "Test alias.", output = "output")
      db.insert(alias)
    except:
      quit("Can't add test alias.")
    try:
      var testAlias2 = newAlias(name = "tests2", path = "/", recursive = false,
          commands = "ls -a", description = "Test alias 2.", output = "output")
      db.insert(testAlias2)
    except:
      quit("Can't add the second test alias.")
  var
    commands = newTable[string, CommandData]()

  proc testCommand(arguments: UserInput; db: DbConn;
      list: CommandLists): ResultCode {.gcsafe, raises: [], contractual.} =
    body:
      echo "test"

# Add a command
  addCommand(name = initLimitedString(capacity = 4, text = "test"),
      command = testCommand, commands = commands)
  assert commands.len == 1, "Failed to add a new command."
# Try to add again the same command
  try:
    addCommand(name = initLimitedString(capacity = 4, text = "test"),
        command = testCommand, commands = commands)
  except CommandsListError:
    discard
  assert commands.len == 1, "Failed to not add an existing command."
# Try to replace built-in command
  try:
    addCommand(name = initLimitedString(capacity = 4, text = "exit"),
        command = testCommand, commands = commands)
  except CommandsListError:
    discard
  assert commands.len == 1, "Failed to not replace a built-in command."

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
  assert commands.len == 0, "Failed to delete a command."
# Try to delete non-existing command
  addCommand(name = initLimitedString(capacity = 5, text = "test2"),
      command = testCommand, commands = commands)
  assert commands.len == 1, "Failed to not delete a non-existing command"
  try:
    deleteCommand(name = initLimitedString(capacity = 4, text = "test"),
        commands = commands)
  except CommandsListError:
    discard
  assert commands.len == 1, "Failed to not delete a previously delete command"

  closeDb(ResultCode(QuitSuccess), db)
