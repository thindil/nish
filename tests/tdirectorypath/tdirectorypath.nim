discard """
  exitcode: 0
"""

import ../../src/directorypath

block:
  let path: DirectoryPath = "/test/path".DirectoryPath

  assert path != "test2", "Failed to compare different paths."
  assert path == "/test/path", "Failed to compare the same paths."

  assert path & "/test" == "/test/path/test", "Failed to append a string to a path."
  assert "/new" & path == "/new/test/path", "Failed to prepend a string to a path."

  assert path.find("e".DirectoryPath) == 2, "Failed to find a substring in a path."
  assert path.find("z".DirectoryPath) == -1, "Failed to not find a substring in a path."

  assert path.len == 10, "Failed to get the length of a path."

  assert $path == "/test/path", "Failed to convert a path to a string."
