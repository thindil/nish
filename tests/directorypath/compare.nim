discard """
  exitcode: 0
"""

import ../../src/directorypath

let path: DirectoryPath = "/test/path".DirectoryPath
assert path != "test2"
assert path == "/test/path"
