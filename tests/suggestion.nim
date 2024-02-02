import utils/utils
import unittest2
include ../src/suggestion

suite "Unit tests for suggestion module":

  checkpoint "Initializing the tests"
  let db = initDb("test14.db")
  var
    myaliases = newOrderedTable[string, int]()
    commands = newTable[string, CommandData]()

  checkpoint "Adding testing aliases if needed"
  db.addAliases

  test "Fill the suggestions list":
    fillSuggestionsList(myaliases, commands)

  test "Get suggestion for a command":
    var start: Natural = 0
    check:
      suggestCommand("la", start, db) in ["ln", "lc"]
