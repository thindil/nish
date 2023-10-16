import ../src/directorypath
import unittest2

suite "Unit tests for directorypath module":
  let path: DirectoryPath = "/test/path".DirectoryPath

  test "Compare paths":
    check:
      path != "test2"
      path == "/test/path"

  test "Append to a path":
    check:
      path & "/test" == "/test/path/test"
      "/new" & path == "/new/test/path"

  test "Find in a path":
    check:
      path.find("e".DirectoryPath) == 2
      path.find("z".DirectoryPath) == -1

  test "Length of a path":
    check:
      path.len == 10

  test "Convert a path to string":
    check:
      $path == "/test/path"
