discard """
  exitcode: 0
"""

import std/[tables]
import ../../src/[constants, history, nish]

let db = startDb("test.db")
assert db != nil
var
    helpContent = initTable[string, HelpEntry]()
    amount = initHistory(db, helpContent)
assert amount > -1
quitShell(ResultCode(QuitSuccess), db)
