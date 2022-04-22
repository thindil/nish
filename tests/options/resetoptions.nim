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
assert resetOptions("reset historyLength", db) == QuitSuccess
assert getOption("historyLength", db) == "500"
quitShell(QuitSuccess, db)
