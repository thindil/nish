discard """
  exitcode: 0
"""

import std/[tables]
import ../../src/[constants, nish, variables]

let db = startDb("test.db")
var
    helpContent = initTable[string, HelpEntry]()
initVariables(helpContent, db)
quitShell(QuitSuccess, db)
