discard """
  exitcode: 0
"""

import std/tables
import ../../src/[commandslist, lstring, nish, resultcode]
import utils/helpers

var
  (db, _) = initTest()
  commands: CommandsList = initTable[string, CommandData]()

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
quitShell(ResultCode(QuitSuccess), db)
