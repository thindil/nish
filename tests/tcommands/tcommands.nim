discard """
  exitcode: 0
  outputsub: "/adfwerewtr"
"""

import std/[strutils, tables]
import ../../src/[aliases, commands, directorypath, lstring, nish, resultcode]
import norm/sqlite

let db = startDb("test3.db".DirectoryPath)
assert db != nil, "Failed to initialize database."
if db.count(Alias) == 0:
  try:
    var alias = newAlias(name = "tests", path = "/", recursive = true,
        commands = "ls -a", description = "Test alias.", output = "output")
    db.insert(alias)
  except:
    quit("Can't add test alias.")
  try:
    var testAlias2 = newAlias(name = "tests2", path = "/", recursive = false,
        commands = "ls -a", description = "Test alias 2.", output = "output")
    db.insert(testAlias2)
  except:
    quit("Can't add the second test alias.")

var myaliases = newOrderedTable[LimitedString, int]()

assert cdCommand("/".DirectoryPath, myaliases, db) == QuitSuccess, "Failed to enter an existing directory."
assert cdCommand("/adfwerewtr".DirectoryPath, myaliases, db) == QuitFailure, "Failed to not enter a non-existing directory."

assert changeDirectory("..".DirectoryPath, myaliases, db) == QuitSuccess, "Failed to change the working directory."
assert changeDirectory("/adfwerewtr".DirectoryPath, myaliases, db) ==
    QuitFailure, "Failed to not change the working directory."

quitShell(ResultCode(QuitSuccess), db)
