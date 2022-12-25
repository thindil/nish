discard """
  exitcode: 0
"""

import std/tables
import ../../src/[commandslist, directorypath, lstring, nish, plugins, resultcode]

block:
  let db = startDb("test13.db".DirectoryPath)
  assert db != nil, "Failed to initialize the database."
  var commands = newTable[string, CommandData]()

  initPlugins(db, commands)

  discard removePlugin(db, initLimitedString(capacity = 8, "remove 1"), commands)
  assert addPlugin(db, initLimitedString(capacity = 23,
      "add tools/testplugin.sh"), commands) == QuitSuccess, "Failed to add a new plugin."
  assert addPlugin(db, initLimitedString(capacity = 23,
      "add tools/testplugin.sh"), commands) == QuitFailure, "Failed to not add an added plugin."
  assert addPlugin(db, initLimitedString(capacity = 26,
      "add tools/testplugin.223sh"), commands) == QuitFailure, "Failed to not add a non-existing plugin."

  assert checkPlugin("tools/testplugin.sh", db, commands).path ==
      "tools/testplugin.sh", "Failed to check a plugin."
  assert checkPlugin("sdfsdfds.df", db, commands).path.len == 0, "Failed to not check a non-existing plugin."

  assert execPlugin("tools/testplugin.sh", ["init"], db, commands).code ==
      QuitSuccess, "Failed to execute initialization of a plugin."
  assert execPlugin("tools/testplugin.sh", ["info"], db, commands).answer.len >
      0, "Failed to get info about a plugin."

  assert listPlugins(initLimitedString(capacity = 4, text = "list"), db) ==
      QuitSuccess, "Failed to show list of enabled plugins."
  assert listPlugins(initLimitedString(capacity = 8, text = "list all"), db) ==
      QuitSuccess, "Failed to show list of all plugins."
  assert listPlugins(initLimitedString(capacity = 13, text = "list werwerew"), db) ==
      QuitSuccess, "Failed to show list of enabled plugings."

  assert togglePlugin(db, initLimitedString(capacity = 9, "disable 1"), true,
      commands) == QuitSuccess, "Failed to disable a plugin."
  assert togglePlugin(db, initLimitedString(capacity = 8, "enable 1"), false,
      commands) == QuitSuccess, "Failed to enable a plugin."
  assert togglePlugin(db, initLimitedString(capacity = 8, "enable 2"), false,
      commands) == QuitFailure, "Failed to not enable an enabled plugin."

  assert removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
      commands) == QuitSuccess, "Failed to remove a plugin."
  assert removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
      commands) == QuitFailure, "Failed to not remove a non-existing plugin."

  quitShell(QuitSuccess.ResultCode, db)
