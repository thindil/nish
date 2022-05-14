discard """
  exitcode: 0
"""

import ../../src/[constants, help]

assert showUnknownHelp("command", "subcommand", "helptype") == QuitFailure
