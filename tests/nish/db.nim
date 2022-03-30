discard """
  exitcode: 0
"""

import std/tables
import ../../src/[constants, history, nish]

let db = startDb("test.db")
assert db != nil
var
    historyIndex: int
    helpContent = initTable[string, HelpEntry]()
historyIndex = initHistory(db, helpContent)
quitShell(QuitSuccess, db)
