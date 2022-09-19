import std/[db_sqlite, tables]
import ../../../src/[commandslist, constants, directorypath, history, nish]

proc initTest*(): DbConn =
  result = startDb("test.db".DirectoryPath)
  assert result != nil
  var
    helpContent = newTable[string, HelpEntry]()
    commands: CommandsList = initTable[string, CommandData]()
  discard initHistory(result, helpContent, commands)
