discard """
  exitcode: 0
"""

import ../../src/directorypath

let path: DirectoryPath = "/test/path".DirectoryPath

assert path != "test2"
assert path == "/test/path"

assert path & "/test" == "/test/path/test"
assert "/new" & path == "/new/test/path"

assert path.find("e".DirectoryPath) == 2
assert path.find("z".DirectoryPath) == -1

assert path.len() == 10

assert $path == "/test/path"
