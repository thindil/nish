discard """
  exitcode: 0
  outputsub: Value for option
"""

import std/tables
import ../../src/[commandslist, directorypath, history, lstring, nish, options, resultcode]

block:
  let db = startDb("test11.db".DirectoryPath)
  assert db != nil, "Failed to initialize the database."
  var commands = newTable[string, CommandData]()
  discard initHistory(db, commands)

  initOptions(commands)
  assert commands.len > 0

  assert getOption(initLimitedString(capacity = 13, text = "historyLength"),
      db).len > 0, "Failed to get value of an option."
  assert getOption(initLimitedString(capacity = 10, text = "werweewfwe"),
      db).len == 0, "Failed to not get a value of a non-existing option."

  let optionName = initLimitedString(capacity = 10, text = "testOption")
  setOption(optionName = optionName, value = initLimitedString(capacity = 3,
      text = "200"), db = db)
  assert deleteOption(optionName, db) == QuitSuccess, "Failed to delete an option."
  assert getOption(optionName, db).len == 0, "Failed to not get a deleted option."

  setOption(optionName = initLimitedString(capacity = 13,
      text = "historyLength"), value = initLimitedString(capacity = 3,
          text = "100"), db = db)
  assert getOption(initLimitedString(capacity = 13, text = "historyLength"),
      db) == "100", "Failed to set a value for an option."

  assert setOptions(initLimitedString(capacity = 22,
      text = "set historyLength 1000"), db) == QuitSuccess, "Failed to set a value for an option."
  assert getOption(initLimitedString(capacity = 13, text = "historyLength"),
      db) == "1000", "Failed to get a new value of an option."

  assert resetOptions(initLimitedString(capacity = 19,
      text = "reset historyLength"), db) == QuitSuccess, "Failed to reset a value for an option."
  assert getOption(initLimitedString(capacity = 13, text = "historyLength"),
      db) == "500", "Failed to get a reseted value for an option."

  assert showOptions(db) == QuitSuccess

  assert newOption(name = "newOpt").option == "newOpt", "Failed to initialize a new option."

  assert dbType(ValueType) == "TEXT", "Failed to get the type of database field for ValueType."

  assert dbValue(text).s == "text", "Failed to convert ValueType to dbValue."

  assert to(dbValue(text), ValueType) == text, "Failed to convert dbValue to ValueType."

  quitShell(ResultCode(QuitSuccess), db)
