discard """
  exitcode: 0
"""

import std/[db_sqlite, tables]
import contracts
import ../../src/[commandslist, constants, lstring, nish, resultcode]
import utils/helpers

var
  (db, _) = initTest()
  commands = newTable[string, CommandData]()

proc testCommand2(arguments: UserInput; db: DbConn;
    list: CommandLists): ResultCode {.gcsafe, raises: [], contractual.} =
  body:
    echo "test2"

# Add a command
addCommand(name = initLimitedString(capacity = 4, text = "test"),
    command = testCommand, commands = commands)
assert commands.len() == 1
# Replace command with new procedure
replaceCommand(name = initLimitedString(capacity = 4, text = "test"),
    command = testCommand2, commands = commands)
# Try to replace non existing command
try:
  replaceCommand(name = initLimitedString(capacity = 4, text = "exit"),
      command = testCommand, commands = commands)
except CommandsListError:
  discard
quitShell(ResultCode(QuitSuccess), db)
