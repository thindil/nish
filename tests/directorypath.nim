import ../src/directorypath
import unittest2

suite "Unit tests for directorypath module":
  let path: DirectoryPath = "/test/path".DirectoryPath

  test "Compare paths":
    checkpoint "Compare different paths"
    check:
      path != "test2"
    checkpoint "Compare the same path"
    check:
      path == "/test/path"

  test "Append to a path":
    checkpoint "Prepend a string to a path"
    check:
      path & "/test" == "/test/path/test"
    checkpoint "Append a string to a path"
    check:
      "/new" & path == "/new/test/path"

  test "Find in a path":
    checkpoint "Find an existing character in a path"
    check:
      path.find("e".DirectoryPath) == 2
    checkpoint "Not find a non-existing character in a path"
    check:
      path.find("z".DirectoryPath) == -1

  test "Length of a path":
    check:
      path.len == 10

  test "Convert a path to string":
    check:
      $path == "/test/path"
