discard """
  exitcode: 0
  outputsub: test
"""

import ../../src/[directorypath, nish, title]

block:
  let db = startDb("test9.db".DirectoryPath)
  assert db != nil, "Failed to initialize the database."

  setTitle("test title", db)
