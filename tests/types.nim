import unittest2
include ../src/types

suite "Unit tests for types module":

  test "Convert Path to string":
    check:
      $("/".Path) == "/"

  test "Count the length of Path":
    check:
      "/".Path.len == 1

  test "Getting the type of the database field for Path":
    check:
      dbType(T = Path) == "TEXT"

  test "Converting dbValue to Path":
    check:
      dbValue(val = "/".Path).s == "/"

  test "Converting Path to dbValue":
    check:
      to(dbVal = "/".dbValue, T = Path) == "/".Path

  test "Compare ResultCode to int":
    let code: ResultCode = QuitSuccess.ResultCode
    check:
      code == QuitSuccess

  test "Convert ResultCode to string":
    let code: ResultCode = QuitSuccess.ResultCode
    check:
      $code == $QuitSuccess

