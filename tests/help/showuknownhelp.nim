discard """
  exitcode: 0
"""

import ../../src/[constants, help, lstring]

assert showUnknownHelp(initLimitedString(capacity = 7, text = "command"),
    initLimitedString(capacity = 10, text = "subcommand"), initLimitedString(
    capacity = 8, text = "helptype")) == QuitFailure
