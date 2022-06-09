discard """
  exitcode: 0
"""

import ../../src/directorypath

let path = "/test/path".DirectoryPath
assert $path == "/test/path"
