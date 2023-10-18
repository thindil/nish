import std/tables
import ../src/[commandslist, db, directorypath, history, lstring, options, resultcode]
import unittest2

suite "Unit tests for options module":

  let db = startDb("test11.db".DirectoryPath)
  assert db != nil, "Failed to initialize the database."
  var commands = newTable[string, CommandData]()
  discard initHistory(db, commands)

  test "initOptions":
    initOptions(commands)
    check:
      commands.len > 0

  test "getOption":
    check:
      getOption(initLimitedString(capacity = 13, text = "historyLength"),
          db).len > 0
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

  test "setOptions":
    check:
      setOptions(initLimitedString(capacity = 22,
          text = "set historyLength 1000"), db) == QuitSuccess
      getOption(initLimitedString(capacity = 13, text = "historyLength"),
          db) == "1000"

  test "resetOptions":
    check:
      resetOptions(initLimitedString(capacity = 19,
          text = "reset historyLength"), db) == QuitSuccess
      getOption(initLimitedString(capacity = 13, text = "historyLength"),
          db) == "500"

  test "showOptions":
    check:
      showOptions(db) == QuitSuccess

  test "newOption":
    check:
      newOption(name = "newOpt").option == "newOpt"

  test "dbType":
    check:
      dbType(ValueType) == "TEXT"

  test "dbValue":
    check:
      dbValue(text).s == "text"

  test "to":
    check:
      to(text.dbValue, ValueType) == text

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
