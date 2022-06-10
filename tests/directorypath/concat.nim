discard """
  exitcode: 0
"""

import ../../src/directorypath

let path: DirectoryPath = "/test/path/".DirectoryPath
assert path & "test" == "/test/path/test"
assert "/new" & path == "/new/test/path/"
