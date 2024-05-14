import std/tables
import utils/utils
import ../src/[aliases, db]
import unittest2
include ../src/help

suite "Unit tests for help module":

  checkpoint "Initializing the tests"
  let db = initDb(dbName = "test6.db")
  var commands = newTable[string, CommandData]()

  test "Initializing the help system":
    initHelp(db = db, commands = commands)
    check:
      commands.len == 2

  test "Adding a new help entry":
    discard deleteHelpEntry(topic = "test", db = db)
    checkpoint "Adding a non-existing help entry"
    check:
      addHelpEntry(topic = "test", usage = "test topic", plugin = "test",
          content = "test help", isTemplate = false, db = db) == QuitSuccess
    checkpoint "Adding an existing help entry"
    check:
      addHelpEntry(topic = "test", usage = "test topic", plugin = "test",
          content = "test help", isTemplate = false, db = db) == QuitFailure

  test "Deleting a help entry":
    discard deleteHelpEntry(topic = "test", db = db)
    check:
      addHelpEntry(topic = "test", usage = "test topic", plugin = "test",
          content = "test help", isTemplate = false, db = db) == QuitSuccess
    checkpoint "Deleting an existing help entry"
    check:
      deleteHelpEntry(topic = "test", db = db) ==
          QuitSuccess
    checkpoint "Deleting a non-existing help entry"
    check:
      deleteHelpEntry(topic = "asdd", db = db) ==
          QuitFailure
    checkpoint "Deleting a deleted help entry"
    check:
      deleteHelpEntry(topic = "test", db = db) ==
          QuitFailure

  test "Updating the help system":
    check:
      updateHelp(db = db) == QuitSuccess

  test "Loading the help content from a file":
    db.exec(query = "DELETE FROM help".sql)
    checkpoint "Loading the help content to the empty help system"
    check:
      readHelpFromFile(db = db) == QuitSuccess
    checkpoint "Loading the help content to the full help system"
    check:
      readHelpFromFile(db = db) == QuitFailure

  test "Showing the help entry":
    checkpoint "Showing an existing help entry"
    check:
      showHelp(topic = "alias", db = db) ==
          QuitSuccess
    checkpoint "Showing a non-existing help entry"
    check:
      showHelp(topic = "srewfdsfs", db = db) ==
          QuitFailure

  test "Showing list of help for a command":
    check:
      showHelpList(command = "alias", subcommands = aliasesCommands, db = db) == QuitSuccess

  test "Showing the unknown help entry screen":
    check:
      showUnknownHelp(subCommand = "command", command = "subcommand",
          helpType = "helptype", db = db) == QuitFailure

  test "Updating a help entry":
    discard deleteHelpEntry("test", db)
    unittest2.require:
      addHelpEntry("test",
          "test topic",
              "test", "test help", false, db) == QuitSuccess
    checkpoint "Updating an existing help entry"
    check:
      updateHelpEntry("test",
          "test topic",
              "test", "test help2", db, false) == QuitSuccess
    checkpoint "Updating a non-existing help entry"
    check:
      updateHelpEntry("asdd",
          "test topic",
              "test", "test help2", db, false) == QuitFailure

  test "Initializing an object of HelpEntry type":
    let newHelp = newHelpEntry(topic = "test")
    check:
      newHelp.topic == "test"

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
