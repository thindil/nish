discard """
  exitcode: 0
"""

import ../../src/resultcode

let code = QuitSuccess.ResultCode
assert $code == $QuitSuccess
