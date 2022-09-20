discard """
  exitcode: 0
"""

import std/tables
import ../../src/[commandslist, lstring, nish, resultcode]
import utils/helpers

var
  (db, _) = initTest()
  commands = newTable[string, CommandData]()

# Add the command
addCommand(name = initLimitedString(capacity = 4, text = "test"),
    command = testCommand, commands = commands)
assert commands.len() == 1
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
