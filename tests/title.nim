import utils/utils
import ../src/title
import unittest2

suite "Unit tests for title module":

  checkpoint "Initializing the tests"
  let db = initDb("test9.db")

  test "Set the terminal title":
    setTitle("test title", db)
