discard """
  exitcode: 0
"""

import ../../src/directorypath

let path: DirectoryPath = "/test/path".DirectoryPath
assert path.len() == 10
