import std/tables
import ../src/[commandslist, db ,directorypath, history, nish, resultcode]
import unittest2

suite "Unit tests for nish module":

  test "showCommandLineHelp":
    showCommandLineHelp()

  test "showProgramVersion":
    showProgramVersion()

  test "The database connection":
    let db = startDb("test10.db".DirectoryPath)
    require:
      db != nil
    var
        historyIndex: int
        commands = newTable[string, CommandData]()
    historyIndex = initHistory(db, commands)
    closeDb(QuitSuccess.ResultCode, db)
