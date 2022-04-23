discard """
  exitcode: 0
"""

import std/[tables]
import ../../src/[constants, options, nish]

let db = startDb("test.db")
assert db != nil
var
    helpContent = initTable[string, HelpEntry]()
initOptions(helpContent)
assert helpContent.len() > 0
quitShell(QuitSuccess, db)
