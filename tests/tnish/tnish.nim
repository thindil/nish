discard """
  exitcode: 0
  outputsub: Available arguments are
"""

import std/tables
import ../../src/[commandslist, db ,directorypath, history, nish, resultcode]

block:
  showCommandLineHelp()

  showProgramVersion()

  let db = startDb("test10.db".DirectoryPath)
  assert db != nil, "Failed to initialize the database."
  var
      historyIndex: int
      commands = newTable[string, CommandData]()
  historyIndex = initHistory(db, commands)
  closeDb(ResultCode(QuitSuccess), db)
