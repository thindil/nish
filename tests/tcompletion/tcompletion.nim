discard """
  exitcode: 0
"""

import std/[db_sqlite, os, strutils, tables]
import ../../src/[aliases, completion, commandslist, directorypath, lstring,
    nish, resultcode]

block:
  let db = startDb("test5.db".DirectoryPath)
  assert db != nil, "No connection to database."
  var
    myaliases = newOrderedTable[LimitedString, int]()
    commands = newTable[string, CommandData]()
    completions: seq[string]
  if parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 0:
    if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
        "tests", "/", 1, "ls -a", "Test alias.") == -1:
      quit("Can't add test alias.")
  if parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 1:
    if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
        "tests2", "/", 0, "ls -a", "Test alias 2.") == -1:
      quit("Can't add the second test alias.")
  initAliases(db, myaliases, commands)

  open("sometest.txt", fmWrite).close
  getDirCompletion("somete", completions, db)
  removeFile("sometest.txt")
  assert completions == @["sometest.txt"], "Failed to get Tab completion for a file."

  getCommandCompletion("exi", completions, myaliases, commands, db)
  assert completions[1] == "exit", "Failed to get Tab completion for a command."

  quitShell(ResultCode(QuitSuccess), db)
