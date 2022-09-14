discard """
  exitcode: 0
"""

import std/[db_sqlite, tables]
import contracts
import ../../src/[commandslist, constants, lstring, nish, resultcode]
import utils/helpers

var
  (db, _) = initTest()
  commands: CommandsList = initTable[string, CommandProc]()

proc testCommand(arguments: UserInput; db: DbConn;
    list: CommandLists): ResultCode {.gcsafe, raises: [], contractual.} =
  body:
    echo "test"

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
