import ../src/databaseid
import unittest2

suite "Unit tests for databaseid module":

  test "Convert DatabaseId to string":
    check:
      $12.Databaseid == "12"
