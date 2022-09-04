discard """
  exitcode: 0
"""

import std/tables
import ../../src/[constants, directorypath, history, nish, resultcode]

let db = startDb("test.db".DirectoryPath)
assert db != nil
var
    historyIndex: int
    helpContent = newTable[string, HelpEntry]()
historyIndex = initHistory(db, helpContent)
quitShell(ResultCode(QuitSuccess), db)
