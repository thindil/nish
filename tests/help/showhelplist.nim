discard """
  exitcode: 0
"""

import ../../src/[aliases, help]
import utils/helpers

var (db, helpContent) = initTest()
updateHelp(helpContent, db)
discard showHelpList("alias", aliasesCommands, db)
