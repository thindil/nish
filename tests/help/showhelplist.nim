discard """
  exitcode: 0
"""

import ../../src/[aliases, help, resultcode]

assert showHelpList("alias", aliasesCommands) == QuitSuccess
