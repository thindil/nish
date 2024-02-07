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
      dbType(Path) == "TEXT"

  test "Converting dbValue to Path":
    check:
      dbValue("/").s == "/"

  test "Converting Path to dbValue":
    check:
      to("/".dbValue, Path) == "/".Path

