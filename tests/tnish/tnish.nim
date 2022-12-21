discard """
  exitcode: 0
"""

import std/tables
import ../../src/[commandslist, directorypath, history, nish, resultcode]

showCommandLineHelp()

showProgramVersion()

let db = startDb("test.db".DirectoryPath)
assert db != nil, "Failed to initialize the database."
var
    historyIndex: int
    commands = newTable[string, CommandData]()
historyIndex = initHistory(db, commands)
quitShell(ResultCode(QuitSuccess), db)
