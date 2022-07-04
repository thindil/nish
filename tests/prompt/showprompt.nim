discard """
  exitcode: 0
"""

import ../../src/[prompt, resultcode]

showPrompt(true, "ls -a", ResultCode(QuitSuccess))
