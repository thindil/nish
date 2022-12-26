discard """
  exitcode: 0
"""

import ../../src/resultcode

block:
  let code: ResultCode = QuitSuccess.ResultCode
  assert code == QuitSuccess, "Failed to compare ResultCode to int."

  assert $code == $QuitSuccess, "Failed to convert ResultCode to string."
