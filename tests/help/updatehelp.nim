discard """
  exitcode: 0
"""

import std/tables
import ../../src/[constants, help, nish]

let db = startDb("test.db")
assert db != nil
var
    helpContent = initTable[string, HelpEntry]()
updateHelp(helpContent, db)
assert helpContent.len() == 1
quitShell(ResultCode(QuitSuccess), db)
