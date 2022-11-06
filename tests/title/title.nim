discard """
  exitcode: 0
"""

import ../../src/[directorypath, nish, title]

let db = startDb("test.db".DirectoryPath)
assert db != nil

setTitle("test title", db)
