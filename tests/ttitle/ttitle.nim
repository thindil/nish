discard """
  exitcode: 0
"""

import ../../src/[db, directorypath, title]

block:
  let db = startDb("test9.db".DirectoryPath)
  assert db != nil, "Failed to initialize the database."

  setTitle("test title", db)
