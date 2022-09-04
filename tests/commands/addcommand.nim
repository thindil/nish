discard """
  exitcode: 0
"""

import std/[db_sqlite, tables]
import contracts
import ../../src/[commands, constants, lstring, nish, resultcode]
import utils/helpers

var
  (db, _) = initTest()
  commandsList: CommandsList = initTable[string, CommandProc]()

proc testCommand(arguments: UserInput; db: DbConn;
    list: CommandLists): ResultCode {.gcsafe, raises: [], contractual.} =
  body:
    echo "test"

addCommand(name = initLimitedString(capacity = 4, text = "test"),
    command = testCommand, commands = commandsList)
assert commandsList.len() == 1
addCommand(name = initLimitedString(capacity = 4, text = "test"),
    command = testCommand, commands = commandsList)
assert commandsList.len() == 1
addCommand(name = initLimitedString(capacity = 4, text = "exit"),
    command = testCommand, commands = commandsList)
assert commandsList.len() == 1
quitShell(ResultCode(QuitSuccess), db)
