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
setMainHelp(helpContent)
assert helpContent.len() == 2
quitShell(ResultCode(QuitSuccess), db)
