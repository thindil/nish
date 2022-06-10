discard """
  exitcode: 0
"""

import ../../src/directorypath

let path: DirectoryPath = "/test/path".DirectoryPath
assert path.find("e".DirectoryPath) == 2
assert path.find("z".DirectoryPath) == -1
