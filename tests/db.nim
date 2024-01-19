import std/tables
import ../src/[db, commandslist, resultcode]
import utils/utils
import unittest2
import norm/sqlite

suite "Unit tests for db module":

  checkpoint "Initializing the tests"
  let db = initDb("test15.db")
  var commands = newTable[string, CommandData]()

  test "Initialization of the shell's database's commands":
    initDb(db, commands)
    check:
      commands.len == 1

  test "Optimizing the shell's database":
    check:
      optimizeDb("optimize", db) == QuitSuccess

  test "Exporting the shell's database":
    check:
      exportDb("export test.txt", db) == QuitSuccess

  test "Importing the shell's database":
    db.exec("DROP TABLE help".sql)
    db.exec("DROP TABLE options".sql)
    db.exec("DROP TABLE theme".sql)
    check:
      importDb("import test.txt", db) == QuitSuccess

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
