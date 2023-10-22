import std/tables
import utils/utils
import ../src/[aliases, commandslist, db, help, lstring, resultcode]
import norm/sqlite
import unittest2

suite "Unit tests for help module":

  checkpoint "Initializing the tests"
  let db = initDb("test6.db")
  var commands = newTable[string, CommandData]()

  test "Initializing the help system":
    initHelp(db, commands)
    check:
      commands.len == 2

  test "Adding a new help entry":
    discard deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db)
    checkpoint "Adding a non-existing help entry"
    check:
      addHelpEntry(initLimitedString(capacity = 4, text = "test"),
          initLimitedString(capacity = 10, text = "test topic"),
              initLimitedString(
          capacity = 4, text = "test"), "test help", false, db) == QuitSuccess
    checkpoint "Adding an existing help entry"
    check:
      addHelpEntry(initLimitedString(capacity = 4, text = "test"),
          initLimitedString(capacity = 10, text = "test topic"),
              initLimitedString(
          capacity = 4, text = "test"), "test help", false, db) == QuitFailure

  test "Deleting a help entry":
    discard deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db)
    check:
      addHelpEntry(initLimitedString(capacity = 4, text = "test"),
          initLimitedString(capacity = 10, text = "test topic"),
              initLimitedString(
          capacity = 4, text = "test"), "test help", false, db) == QuitSuccess
    checkpoint "Deleting an existing help entry"
    check:
      deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db) ==
          QuitSuccess
    checkpoint "Deleting a non-existing help entry"
    check:
      deleteHelpEntry(initLimitedString(capacity = 4, text = "asdd"), db) ==
          QuitFailure
    checkpoint "Deleting a deleted help entry"
    check:
      deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db) ==
          QuitFailure

  test "Updating the help system":
    check:
      updateHelp(db) == QuitSuccess

  test "Loading the help content from a file":
    db.exec(sql("DELETE FROM help"))
    checkpoint "Loading the help content to the empty help system"
    check:
      readHelpFromFile(db) == QuitSuccess
    checkpoint "Loading the help content to the full help system"
    check:
      readHelpFromFile(db) == QuitFailure

  test "Showing the help entry":
    checkpoint "Showing an existing help entry"
    check:
      showHelp(initLimitedString(capacity = 12, text = "alias"), db) ==
          QuitSuccess
    checkpoint "Showing a non-existing help entry"
    check:
      showHelp(initLimitedString(capacity = 9, text = "srewfdsfs"), db) ==
          QuitFailure

  test "Showing list of help for a command":
    check:
      showHelpList("alias", aliasesCommands) == QuitSuccess

  test "Showing the unknown help entry screen":
    check:
      showUnknownHelp(initLimitedString(capacity = 7, text = "command"),
          initLimitedString(capacity = 10, text = "subcommand"),
              initLimitedString(
          capacity = 8, text = "helptype")) == QuitFailure

  test "Updating a help entry":
    discard deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db)
    require:
      addHelpEntry(initLimitedString(capacity = 4, text = "test"),
          initLimitedString(capacity = 10, text = "test topic"),
              initLimitedString(
          capacity = 4, text = "test"), "test help", false, db) == QuitSuccess
    checkpoint "Updating an existing help entry"
    check:
      updateHelpEntry(initLimitedString(capacity = 4, text = "test"),
          initLimitedString(capacity = 10, text = "test topic"),
              initLimitedString(
          capacity = 4, text = "test"), "test help2", db, false) == QuitSuccess
    checkpoint "Updating a non-existing help entry"
    check:
      updateHelpEntry(initLimitedString(capacity = 4, text = "asdd"),
          initLimitedString(capacity = 10, text = "test topic"),
              initLimitedString(
          capacity = 4, text = "test"), "test help2", db, false) == QuitFailure

  test "Initializing an object of HelpEntry type":
    let newHelp = newHelpEntry(topic = "test")
    check:
      newHelp.topic == "test"

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
