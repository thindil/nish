discard """
  exitcode: 0
"""

import std/tables
import ../../src/[constants, history, nish, options]

let db = startDb("test.db")
assert db != nil
var
    historyIndex: int
    helpContent = initTable[string, HelpEntry]()
historyIndex = initHistory(db, helpContent)
assert getOption("historyLength", db).len() > 0
assert getOption("werweewfwe", db).len() == 0
quitShell(QuitSuccess, db)
