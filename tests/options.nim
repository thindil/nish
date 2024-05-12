import utils/utils
import ../src/[db, history]
import unittest2
{.warning[UnusedImport]: off.}
include ../src/options

suite "Unit tests for options module":

  checkpoint "Initializing the tests"
  let db = initDb(dbName = "test11.db")
  var commands = newTable[string, CommandData]()
  discard initHistory(db = db, commands = commands)

  test "Initializiation of the shell's options":
    initOptions(commands = commands, db = db)
    check:
      commands.len > 0

  test "Getting the value of an option":
    checkpoint "Getting the value of an existing option"
    check:
      getOption(optionName = "historyLength", db = db).len > 0
    checkpoint "Getting the value of a non-existing option"
    check:
      getOption(optionName = "werweewfwe", db = db).len == 0

  test "Adding a new option":
    let optionName = "testOption"
    setOption(optionName = optionName, value = "200", db = db)
    check:
      deleteOption(optionName = optionName, db = db) == QuitSuccess
      getOption(optionName = optionName, db = db).len == 0

  test "Updating an existing option":
    setOption(optionName = "historyLength", value = "100", db = db)
    check:
      getOption(optionName = "historyLength", db = db) == "100"

  test "Setting the new value for an option":
    when not defined(testInput):
      skip()
    else:
      check:
        setOptions(db = db) == QuitSuccess
        getOption(optionName = "colorSyntax", db = db) == "true"

  test "Resetting the shell's options":
    check:
      resetOptions(arguments = "reset all", db = db) == QuitSuccess
      getOption(optionName = "historyLength", db = db) == "500"

  test "Showing all options":
    check:
      showOptions(db = db) == QuitSuccess

  test "Initializing an object of Option type":
    check:
      newOption(name = "newOpt").option == "newOpt"

  test "Getting the type of the database field for OptionValType":
    check:
      dbType(T = OptionValType) == "TEXT"

  test "Converting dbValue to OptionValType":
    check:
      dbValue(val = text).s == "text"

  test "Converting OptionValType to dbValue":
    check:
      to(dbVal = text.dbValue, T = OptionValType) == text

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
