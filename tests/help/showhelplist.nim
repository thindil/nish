discard """
  exitcode: 0
"""

import ../../src/[aliases, help, resultcode]
import utils/helpers

var (db, helpContent) = initTest()
updateHelp(helpContent, db)
assert showHelpList("alias", aliasesCommands) == QuitSuccess
