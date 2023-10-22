import std/tables
import utils/utils
import ../src/[commandslist, db, history, lstring, options, resultcode]
import unittest2

suite "Unit tests for options module":

  checkpoint "Initializing the tests"
  let db = initDb("test11.db")
  var commands = newTable[string, CommandData]()
  discard initHistory(db, commands)

  test "Initializiation of the shell's options":
    initOptions(commands)
    check:
      commands.len > 0

  test "Getting the value of an option":
    checkpoint "Getting the value of an existing option"
    check:
      getOption(initLimitedString(capacity = 13, text = "historyLength"),
          db).len > 0
    checkpoint "Getting the value of a non-existing option"
    check:
      getOption(initLimitedString(capacity = 10, text = "werweewfwe"),
          db).len == 0

  test "Adding a new option":
    let optionName = initLimitedString(capacity = 10, text = "testOption")
    setOption(optionName = optionName, value = initLimitedString(capacity = 3,
        text = "200"), db = db)
    check:
      deleteOption(optionName, db) == QuitSuccess
      getOption(optionName, db).len == 0

  test "Updating an existing option":
    setOption(optionName = initLimitedString(capacity = 13,
          text = "historyLength"), value = initLimitedString(capacity = 3,
          text = "100"), db = db)
    check:
      getOption(initLimitedString(capacity = 13, text = "historyLength"),
          db) == "100"

  test "Setting the new value for an option":
    check:
      setOptions(initLimitedString(capacity = 22,
          text = "set historyLength 1000"), db) == QuitSuccess
      getOption(initLimitedString(capacity = 13, text = "historyLength"),
          db) == "1000"

  test "Resetting the shell's options":
    check:
      resetOptions(initLimitedString(capacity = 19,
          text = "reset historyLength"), db) == QuitSuccess
      getOption(initLimitedString(capacity = 13, text = "historyLength"),
          db) == "500"

  test "Showing all options":
    check:
      showOptions(db) == QuitSuccess

  test "Initializing an object of Option type":
    check:
      newOption(name = "newOpt").option == "newOpt"

  test "Getting the type of the database field for ValueType":
    check:
      dbType(ValueType) == "TEXT"

  test "Converting dbValue to ValueType":
    check:
      dbValue(text).s == "text"

  test "Converting ValueType to dbValue":
    check:
      to(text.dbValue, ValueType) == text

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
