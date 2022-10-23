discard """
  exitcode: 0
"""

import ../../src/resultcode

let code: ResultCode = QuitSuccess.ResultCode
assert code == QuitSuccess

assert $code == $QuitSuccess
