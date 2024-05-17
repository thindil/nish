import std/tables
import utils/utils
import unittest2
include ../src/db

suite "Unit tests for db module":

  checkpoint "Initializing the tests"
  let db = initDb(dbName = "test15.db")
  var commands = newTable[string, CommandData]()

  test "Initialization of the shell's database's commands":
    initDb(db = db, commands = commands)
    check:
      commands.len == 1

  test "Optimizing the shell's database":
    check:
      optimizeDb(arguments = "optimize", db = db) == QuitSuccess

  test "Exporting the shell's database":
    check:
      exportDb(arguments = "export test.txt", db = db) == QuitSuccess

  test "Importing the shell's database":
    db.exec(query = "DROP TABLE help".sql)
    db.exec(query = "DROP TABLE options".sql)
    db.exec(query = "DROP TABLE theme".sql)
    check:
      importDb(arguments = "import test.txt", db = db) == QuitSuccess

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
