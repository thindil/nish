import ../src/resultcode
import unittest2

suite "Unit tests for resultcode module":

  test "Compare ResultCode to int":
    let code: ResultCode = QuitSuccess.ResultCode
    check:
      code == QuitSuccess

  test "Convert ResultCode to string":
    let code: ResultCode = QuitSuccess.ResultCode
    check:
      $code == $QuitSuccess
