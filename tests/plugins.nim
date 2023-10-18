import std/tables
import ../src/[commandslist, db, directorypath, lstring, plugins, resultcode]
import unittest2

suite "Unit tests for plugins module":

  let db = startDb("test13.db".DirectoryPath)
  assert db != nil, "Failed to initialize the database."
  var commands = newTable[string, CommandData]()

  test "initPlugins":
    initPlugins(db, commands)

  test "addPlugin":
    discard removePlugin(db, initLimitedString(capacity = 8, "remove 1"), commands)
    check:
      addPlugin(db, initLimitedString(capacity = 23,
          "add tools/testplugin.sh"), commands) == QuitSuccess
      addPlugin(db, initLimitedString(capacity = 23,
          "add tools/testplugin.sh"), commands) == QuitFailure
      addPlugin(db, initLimitedString(capacity = 26,
          "add tools/testplugin.223sh"), commands) == QuitFailure

  test "checkPlugin":
    check:
      checkPlugin("tools/testplugin.sh", db, commands).path ==
          "tools/testplugin.sh"
      checkPlugin("sdfsdfds.df", db, commands).path.len == 0

  test "execPlugin":
    check:
      execPlugin("tools/testplugin.sh", ["init"], db, commands).code ==
          QuitSuccess
      execPlugin("tools/testplugin.sh", ["info"], db, commands).answer.len >
          0

  test "listPlugins":
    check:
      listPlugins(initLimitedString(capacity = 4, text = "list"), db) ==
          QuitSuccess
      listPlugins(initLimitedString(capacity = 8, text = "list all"), db) ==
          QuitSuccess
      listPlugins(initLimitedString(capacity = 13, text = "list werwerew"),
          db) ==
          QuitSuccess

  test "togglePlugin":
    check:
      togglePlugin(db, initLimitedString(capacity = 9, "disable 1"), true,
          commands) == QuitSuccess
      togglePlugin(db, initLimitedString(capacity = 8, "enable 1"), false,
          commands) == QuitSuccess
      togglePlugin(db, initLimitedString(capacity = 8, "enable 2"), false,
          commands) == QuitFailure

  test "removePlugin":
    check:
      removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
          commands) == QuitSuccess
      removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
          commands) == QuitFailure

  test "newPlugin":
    let newPlugin = newPlugin(path = "/")
    check:
      newPlugin.location == "/"

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
