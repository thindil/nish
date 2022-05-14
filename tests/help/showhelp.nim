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
assert showHelp("history show", helpContent, db) == QuitSuccess
assert showHelp("srewfdsfs", helpContent, db) == QuitFailure
quitShell(ResultCode(QuitSuccess), db)
