import ../src/[db, directorypath, title]
import unittest2

suite "Unit tests for title module":

  let db = startDb("test9.db".DirectoryPath)
  assert db != nil, "Failed to initialize the database."

  test "Set the terminal title":
    setTitle("test title", db)
