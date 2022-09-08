discard """
  exitcode: 0
"""

import std/tables
import ../../src/[constants, commandslist, directorypath, history, nish, resultcode]

let db = startDb("test.db".DirectoryPath)
assert db != nil
var
    historyIndex: int
    helpContent = newTable[string, HelpEntry]()
    commands: CommandsList = initTable[string, CommandProc]()
historyIndex = initHistory(db, helpContent, commands)
quitShell(ResultCode(QuitSuccess), db)
