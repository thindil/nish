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

addCommand(name = initLimitedString(capacity = 4, text = "test"),
    command = testCommand, commands = commands)
assert commands.len() == 1
addCommand(name = initLimitedString(capacity = 4, text = "test"),
    command = testCommand, commands = commands)
assert commands.len() == 1
addCommand(name = initLimitedString(capacity = 4, text = "exit"),
    command = testCommand, commands = commands)
assert commands.len() == 1
quitShell(ResultCode(QuitSuccess), db)
