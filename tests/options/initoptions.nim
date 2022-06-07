discard """
  exitcode: 0
"""

import std/[tables]
import ../../src/[constants, options, nish, resultcode]

let db = startDb("test.db".DirectoryPath)
assert db != nil
var
    helpContent = initTable[string, HelpEntry]()
initOptions(helpContent)
assert helpContent.len() > 0
quitShell(ResultCode(QuitSuccess), db)
