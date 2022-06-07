discard """
  exitcode: 0
"""

import ../../src/[output, resultcode]

showPrompt(true, "ls -a", ResultCode(QuitSuccess))
