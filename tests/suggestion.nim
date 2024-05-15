import utils/utils
import unittest2
include ../src/suggestion

suite "Unit tests for suggestion module":

  checkpoint "Initializing the tests"
  let db = initDb(dbName = "test14.db")
  var
    myaliases = newOrderedTable[string, int]()
    commands = newTable[string, CommandData]()

  checkpoint "Adding testing aliases if needed"
  db.addAliases

  test "Fill the suggestions list":
    fillSuggestionsList(aliases = myaliases, commands = commands)

  test "Get suggestion for a command":
    var start: Natural = 0
    check:
      suggestCommand(invalidName = "la", start = start, db = db) in ["ln", "lc"]
