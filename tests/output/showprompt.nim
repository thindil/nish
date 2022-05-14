discard """
  exitcode: 0
"""

import ../../src/[constants, output]

showPrompt(true, "ls -a", ResultCode(QuitSuccess))
