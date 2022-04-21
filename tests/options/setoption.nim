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
setOption(optionName = "historyLength", value = "100", db = db)
assert getOption("historyLength", db) == "100"
quitShell(QuitSuccess, db)
