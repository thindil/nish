discard """
  exitcode: 0
  outputsub: "available aliases are"
"""

import std/[os, strutils, tables]
import ../../src/[aliases, directorypath, commandslist, lstring, nish, resultcode]
import contracts
import norm/sqlite

let db = startDb("test2.db".DirectoryPath)
assert db != nil, "No connection to database."
var
  myaliases = newOrderedTable[LimitedString, int]()
  commands = newTable[string, CommandData]()

if db.count(Alias) == 0:
  try:
    var alias = newAlias(name = "tests", path = "/", recursive = true,
        commands = "ls -a", description = "Test alias.", output = "output")
    db.insert(alias)
  except:
    quit("Can't add test alias.")
if db.count(Alias) == 1:
  try:
    var testAlias2 = newAlias(name = "tests2", path = "/", recursive = false,
        commands = "ls -a", description = "Test alias 2.", output = "output")
    db.insert(testAlias2)
  except:
    quit("Can't add the second test alias.")

initAliases(db, myaliases, commands)
assert myaliases.len == 1, "Failed to set aliases for current directory."


assert deleteAlias(initLimitedString(capacity = 8, text = "delete 2"),
    myaliases, db) == QuitSuccess, "Failed to delete an alias."
assert db.count(Alias) == 1
assert deleteAlias(initLimitedString(capacity = 9, text = "delete 22"),
    myaliases, db) == QuitFailure, "Failed to not delete a non-existing alias."
try:
  var testAlias2 = newAlias(name = "tests2", path = "/", recursive = false,
      commands = "ls -a", description = "Test alias 2.", output = "output")
  db.insert(testAlias2)
except:
  quit("Can't add test2 alias.")
assert db.count(Alias) == 2, "Failed to re-add an alias."

myaliases.setAliases(getCurrentDir().DirectoryPath, db)
assert execAlias(emptyLimitedString(), "tests", myaliases, db) == QuitSuccess, "Failed to execute an alias."
assert execAlias(emptyLimitedString(), "tests2", myaliases, db) ==
    QuitFailure, "Failed to not execute a noon-existing alias."

assert db.count(Alias) == 2
assert listAliases(initLimitedString(capacity = 4, text = "list"), myaliases,
    db) == QuitSuccess, "Failed to show the list of available aliases."
assert listAliases(initLimitedString(capacity = 8, text = "list all"),
    myaliases, db) == QuitSuccess, "Failed to show the list of all aliases."
try:
  assert listAliases(initLimitedString(capacity = 8, text = "werwerew"),
      myaliases, db) == QuitSuccess
except PreConditionDefect:
  discard

let newAlias = newAlias(name = "ala")
assert newAlias.name == "ala", "Failed to set a new alias."

quitShell(ResultCode(QuitSuccess), db)
