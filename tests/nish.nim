import std/tables
import utils/utils
import ../src/[commandslist, history, nish]
import unittest2

suite "Unit tests for nish module":

  test "Showing the list of available options for the shell":
    showCommandLineHelp()

  test "Showing the shell's version":
    showProgramVersion()

  test "The database connection":
    let db = initDb("test10.db")
    var
        historyIndex: int
        commands = newTable[string, CommandData]()
    historyIndex = initHistory(db, commands)
