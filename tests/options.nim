import std/tables
import utils/utils
import ../src/[constants, commandslist, db, history, options, resultcode]
import unittest2

suite "Unit tests for options module":

  checkpoint "Initializing the tests"
  let db = initDb("test11.db")
  var commands = newTable[string, CommandData]()
  discard initHistory(db, commands)

  test "Initializiation of the shell's options":
    initOptions(commands, db = db)
    check:
      commands.len > 0

  test "Getting the value of an option":
    checkpoint "Getting the value of an existing option"
    check:
      getOption("historyLength",
          db).len > 0
    checkpoint "Getting the value of a non-existing option"
    check:
      getOption("werweewfwe",
          db).len == 0

  test "Adding a new option":
    let optionName = "testOption"
    setOption(optionName = optionName, value = "200", db = db)
    check:
      deleteOption(optionName, db) == QuitSuccess
      getOption(optionName, db).len == 0

  test "Updating an existing option":
    setOption(optionName = "historyLength", value = "100", db = db)
    check:
      getOption("historyLength",
          db) == "100"

  test "Setting the new value for an option":
    when not defined(testInput):
      skip()
    else:
      check:
        setOptions(db) == QuitSuccess
        getOption(initLimitedString(capacity = 13, text = "colorSyntax"),
            db) == "true"

  test "Resetting the shell's options":
    check:
      resetOptions("reset all", db) == QuitSuccess
      getOption("historyLength",
          db) == "500"

  test "Showing all options":
    check:
      showOptions(db) == QuitSuccess

  test "Initializing an object of Option type":
    check:
      newOption(name = "newOpt").option == "newOpt"

  test "Getting the type of the database field for OptionValType":
    check:
      dbType(OptionValType) == "TEXT"

  test "Converting dbValue to OptionValType":
    check:
      dbValue(text).s == "text"

  test "Converting OptionValType to dbValue":
    check:
      to(text.dbValue, OptionValType) == text

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
