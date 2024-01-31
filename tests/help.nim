import std/tables
import utils/utils
import ../src/[aliases, db]
import unittest2
include ../src/help

suite "Unit tests for help module":

  checkpoint "Initializing the tests"
  let db = initDb("test6.db")
  var commands = newTable[string, CommandData]()

  test "Initializing the help system":
    initHelp(db, commands)
    check:
      commands.len == 2

  test "Adding a new help entry":
    discard deleteHelpEntry("test", db)
    checkpoint "Adding a non-existing help entry"
    check:
      addHelpEntry("test",
          "test topic",
              "test", "test help", false, db) == QuitSuccess
    checkpoint "Adding an existing help entry"
    check:
      addHelpEntry("test",
          "test topic",
              "test", "test help", false, db) == QuitFailure

  test "Deleting a help entry":
    discard deleteHelpEntry("test", db)
    check:
      addHelpEntry("test",
          "test topic",
              "test", "test help", false, db) == QuitSuccess
    checkpoint "Deleting an existing help entry"
    check:
      deleteHelpEntry("test", db) ==
          QuitSuccess
    checkpoint "Deleting a non-existing help entry"
    check:
      deleteHelpEntry("asdd", db) ==
          QuitFailure
    checkpoint "Deleting a deleted help entry"
    check:
      deleteHelpEntry("test", db) ==
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
      showHelp("alias", db) ==
          QuitSuccess
    checkpoint "Showing a non-existing help entry"
    check:
      showHelp("srewfdsfs", db) ==
          QuitFailure

  test "Showing list of help for a command":
    check:
      showHelpList("alias", aliasesCommands, db = db) == QuitSuccess

  test "Showing the unknown help entry screen":
    check:
      showUnknownHelp("command",
          "subcommand",
          "helptype", db = db) == QuitFailure

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
