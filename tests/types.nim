import unittest2
include ../src/types

suite "Unit tests for types module":

  test "Convert Path to string":
    check:
      $("/".Path) == "/"

  test "Count the length of Path":
    check:
      "/".Path.len == 1
