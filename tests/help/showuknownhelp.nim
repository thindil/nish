discard """
  exitcode: 0
"""

import ../../src/help

assert showUnknownHelp("command", "subcommand", "helptype") == QuitFailure
