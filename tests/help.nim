import std/tables
import ../src/[aliases, commandslist, db, directorypath, help, lstring, resultcode]
import norm/sqlite
import unittest2

suite "Unit tests for help module":

  let db = startDb("test6.db".DirectoryPath)
  assert db != nil, "Failed to initialize the database."
  var commands = newTable[string, CommandData]()

  test "initHelp":
    initHelp(db, commands)
    check:
      commands.len == 2

  test "deleteHelpEntry":
    discard deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db)
    check:
      addHelpEntry(initLimitedString(capacity = 4, text = "test"),
          initLimitedString(capacity = 10, text = "test topic"),
              initLimitedString(
          capacity = 4, text = "test"), "test help", false, db) == QuitSuccess
      addHelpEntry(initLimitedString(capacity = 4, text = "test"),
          initLimitedString(capacity = 10, text = "test topic"),
              initLimitedString(
          capacity = 4, text = "test"), "test help", false, db) == QuitFailure

  test "addHelpEntry":
    discard deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db)
    check:
      addHelpEntry(initLimitedString(capacity = 4, text = "test"),
          initLimitedString(capacity = 10, text = "test topic"),
              initLimitedString(
          capacity = 4, text = "test"), "test help", false, db) == QuitSuccess
      deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db) ==
          QuitSuccess
      deleteHelpEntry(initLimitedString(capacity = 4, text = "asdd"), db) ==
          QuitFailure
      deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db) ==
          QuitFailure

  test "updateHelp":
    check:
      updateHelp(db) == QuitSuccess

  test "readHelpFromFile":
    db.exec(sql("DELETE FROM help"))
    check:
      readHelpFromFile(db) == QuitSuccess
      readHelpFromFile(db) == QuitFailure

  test "showHelp":
    check:
      showHelp(initLimitedString(capacity = 12, text = "alias"), db) ==
          QuitSuccess
      showHelp(initLimitedString(capacity = 9, text = "srewfdsfs"), db) ==
          QuitFailure

  test "showHelpList":
    check:
      showHelpList("alias", aliasesCommands) == QuitSuccess

  test "showUnknownHelp":
    check:
      showUnknownHelp(initLimitedString(capacity = 7, text = "command"),
          initLimitedString(capacity = 10, text = "subcommand"),
              initLimitedString(
          capacity = 8, text = "helptype")) == QuitFailure

  test "updateHelpEntry":
    discard deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db)
    require:
      addHelpEntry(initLimitedString(capacity = 4, text = "test"),
          initLimitedString(capacity = 10, text = "test topic"),
              initLimitedString(
          capacity = 4, text = "test"), "test help", false, db) == QuitSuccess
    check:
      updateHelpEntry(initLimitedString(capacity = 4, text = "test"),
          initLimitedString(capacity = 10, text = "test topic"),
              initLimitedString(
          capacity = 4, text = "test"), "test help2", db, false) == QuitSuccess
      updateHelpEntry(initLimitedString(capacity = 4, text = "asdd"),
          initLimitedString(capacity = 10, text = "test topic"),
              initLimitedString(
          capacity = 4, text = "test"), "test help2", db, false) == QuitFailure

  test "newHelp":
    let newHelp = newHelpEntry(topic = "test")
    check:
      newHelp.topic == "test"

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
