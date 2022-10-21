discard """
  exitcode: 0
"""
import std/[db_sqlite, tables]
import ../../src/[aliases, commandslist, directorypath, help, lstring, nish, resultcode]

let db =  startDb("test.db".DirectoryPath)
assert db != nil
var commands = newTable[string, CommandData]()

initHelp(db, commands)
assert commands.len() == 2

discard deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db)
assert addHelpEntry(initLimitedString(capacity = 4, text = "test"),
    initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
    capacity = 4, text = "test"), "test help", false, db) == QuitSuccess
assert addHelpEntry(initLimitedString(capacity = 4, text = "test"),
    initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
    capacity = 4, text = "test"), "test help", false, db) == QuitFailure


discard deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db)
assert addHelpEntry(initLimitedString(capacity = 4, text = "test"),
    initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
    capacity = 4, text = "test"), "test help", false, db) == QuitSuccess
assert deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db) == QuitSuccess
assert deleteHelpEntry(initLimitedString(capacity = 4, text = "asdd"), db) == QuitFailure
assert deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db) == QuitFailure

assert updateHelp(db) == QuitSuccess

db.exec(sql("DELETE FROM help"))
assert readHelpFromFile(db) == QuitSuccess
assert readHelpFromFile(db) == QuitFailure

assert showHelp(initLimitedString(capacity = 12, text = "alias"), db) == QuitSuccess
assert showHelp(initLimitedString(capacity = 9, text = "srewfdsfs"), db) == QuitFailure

assert showHelpList("alias", aliasesCommands) == QuitSuccess

assert showUnknownHelp(initLimitedString(capacity = 7, text = "command"),
    initLimitedString(capacity = 10, text = "subcommand"), initLimitedString(
    capacity = 8, text = "helptype")) == QuitFailure

discard deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db)
assert addHelpEntry(initLimitedString(capacity = 4, text = "test"),
    initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
    capacity = 4, text = "test"), "test help", false, db) == QuitSuccess
assert updateHelpEntry(initLimitedString(capacity = 4, text = "test"),
    initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
    capacity = 4, text = "test"), "test help2", db, false) == QuitSuccess
assert updateHelpEntry(initLimitedString(capacity = 4, text = "asdd"),
    initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
    capacity = 4, text = "test"), "test help2", db, false) == QuitFailure

quitShell(ResultCode(QuitSuccess), db)
