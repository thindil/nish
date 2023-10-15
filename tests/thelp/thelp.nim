discard """
  exitcode: 0
  outputsub: delete the help entry for topic
"""
import std/tables
import ../../src/[aliases, commandslist, db, directorypath, help, lstring, resultcode]
import norm/sqlite

block:
  let db = startDb("test6.db".DirectoryPath)
  assert db != nil, "Failed to initialize the database."
  var commands = newTable[string, CommandData]()

  initHelp(db, commands)
  assert commands.len == 2, "Failed to initialize the help system."

  discard deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db)
  assert addHelpEntry(initLimitedString(capacity = 4, text = "test"),
      initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
      capacity = 4, text = "test"), "test help", false, db) == QuitSuccess, "Failed to add a new help entry."
  assert addHelpEntry(initLimitedString(capacity = 4, text = "test"),
      initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
      capacity = 4, text = "test"), "test help", false, db) == QuitFailure, "Failed to not add an existing help entry."


  discard deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db)
  assert addHelpEntry(initLimitedString(capacity = 4, text = "test"),
      initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
      capacity = 4, text = "test"), "test help", false, db) == QuitSuccess, "Failed to readd a help entry."
  assert deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db) ==
      QuitSuccess, "Failed to delete a help entry."
  assert deleteHelpEntry(initLimitedString(capacity = 4, text = "asdd"), db) ==
      QuitFailure, "Failed to not delete a non-exisiting help entry."
  assert deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db) ==
      QuitFailure, "Failed to not delete a previously deleted help entry."

  assert updateHelp(db) == QuitSuccess, "Failed to updated the help system."

  db.exec(sql("DELETE FROM help"))
  assert readHelpFromFile(db) == QuitSuccess, "Failed to read the help content from a file."
  assert readHelpFromFile(db) == QuitFailure, "Failed to not read again the help content from the same file."

  assert showHelp(initLimitedString(capacity = 12, text = "alias"), db) ==
      QuitSuccess, "Failed to show an existing help entry."
  assert showHelp(initLimitedString(capacity = 9, text = "srewfdsfs"), db) ==
      QuitFailure, "Failed to not show a non-existing help entry."

  assert showHelpList("alias", aliasesCommands) == QuitSuccess, "Failed to show a list of subcommands."

  assert showUnknownHelp(initLimitedString(capacity = 7, text = "command"),
      initLimitedString(capacity = 10, text = "subcommand"), initLimitedString(
      capacity = 8, text = "helptype")) == QuitFailure, "Failed to show the info about unknown help command."

  discard deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db)
  assert addHelpEntry(initLimitedString(capacity = 4, text = "test"),
      initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
      capacity = 4, text = "test"), "test help", false, db) == QuitSuccess, "Failed to readd an existing help entry."
  assert updateHelpEntry(initLimitedString(capacity = 4, text = "test"),
      initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
      capacity = 4, text = "test"), "test help2", db, false) == QuitSuccess, "Failed to update an existing help entry."
  assert updateHelpEntry(initLimitedString(capacity = 4, text = "asdd"),
      initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
      capacity = 4, text = "test"), "test help2", db, false) == QuitFailure, "Failed to not update a non-existing help entry."

  let newHelp = newHelpEntry(topic = "test")
  assert newHelp.topic == "test", "Failed to set a new help entry."

  closeDb(ResultCode(QuitSuccess), db)
