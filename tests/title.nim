import ../src/[db, directorypath, title]
import unittest2

suite "Unit tests for title module":

  checkpoint "Initializing the tests"
  let db = startDb("test9.db".DirectoryPath)
  require:
    db != nil

  test "Set the terminal title":
    setTitle("test title", db)
