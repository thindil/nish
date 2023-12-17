import ../src/[db, resultcode, theme]
import utils/utils
import unittest2

suite "Unit tests for theme module":

  checkpoint "Initializing the tests"
  let db = initDb("test16.db")

  test "Initializing an object of Color type":
    let newColor = newColor(description = "test color")
    check:
      newColor.description == "test color"

  test "Getting the type of the database field for ColorName":
    check:
      dbType(ColorName) == "TEXT"

  test "Converting dbValue to ColorName":
    check:
      dbValue(black).s == "black"

  test "Converting ColorName to dbValue":
    check:
      to(black.dbValue, ColorName) == black

  test "Getting the type of the database field for ThemeColor":
    check:
      dbType(ThemeColor) == "TEXT"

  test "Converting dbValue to ThemeColor":
    check:
      dbValue(errors).s == "errors"

  test "Converting ThemeColor to dbValue":
    check:
      to(errors.dbValue, ThemeColor) == errors

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
