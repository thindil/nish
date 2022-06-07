discard """
  exitcode: 0
"""

import std/tables
import ../../src/[constants, history, nish, resultcode]

let db = startDb("test.db".DirectoryPath)
assert db != nil
var
    historyIndex: int
    helpContent = initTable[string, HelpEntry]()
historyIndex = initHistory(db, helpContent)
quitShell(ResultCode(QuitSuccess), db)
