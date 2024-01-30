import unittest2
{.warning[UnusedImport]:off.}
include ../src/databaseid

suite "Unit tests for databaseid module":

  test "Convert DatabaseId to string":
    check:
      $12.Databaseid == "12"
