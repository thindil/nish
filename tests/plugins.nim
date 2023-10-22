import std/tables
import ../src/[commandslist, db, directorypath, lstring, plugins, resultcode]
import unittest2

suite "Unit tests for plugins module":

  checkpoint "Initializing the tests"
  let db = startDb("test13.db".DirectoryPath)
  require:
    db != nil
  var commands = newTable[string, CommandData]()

  test "Initialization of plugins":
    initPlugins(db, commands)

  test "Adding a new plugin":
    discard removePlugin(db, initLimitedString(capacity = 8, "remove 1"), commands)
    checkpoint "Adding an existing, not added plugin"
    check:
      addPlugin(db, initLimitedString(capacity = 23,
          "add tools/testplugin.sh"), commands) == QuitSuccess
    checkpoint "Adding an existing, previously added plugin"
    check:
      addPlugin(db, initLimitedString(capacity = 23,
          "add tools/testplugin.sh"), commands) == QuitFailure
    checkpoint "Adding a non-existing plugin"
    check:
      addPlugin(db, initLimitedString(capacity = 26,
          "add tools/testplugin.223sh"), commands) == QuitFailure

  test "Checking a plugin":
    checkpoint "Checking an existing plugin"
    check:
      checkPlugin("tools/testplugin.sh", db, commands).path ==
          "tools/testplugin.sh"
    checkpoint "Cheking a non-existing plugin"
    check:
      checkPlugin("sdfsdfds.df", db, commands).path.len == 0

  test "Executing a plugin":
    check:
      execPlugin("tools/testplugin.sh", ["init"], db, commands).code ==
          QuitSuccess
      execPlugin("tools/testplugin.sh", ["info"], db, commands).answer.len >
          0

  test "Showing plugins":
    checkpoint "Showing enabled plugins"
    check:
      listPlugins(initLimitedString(capacity = 4, text = "list"), db) ==
          QuitSuccess
    checkpoint "Showing all plugins"
    check:
      listPlugins(initLimitedString(capacity = 8, text = "list all"), db) ==
          QuitSuccess
    checkpoint "Showing enabled plugins with invalid subcommand"
    check:
      listPlugins(initLimitedString(capacity = 13, text = "list werwerew"),
          db) == QuitSuccess

  test "Enabling or disabling a plugin":
    checkpoint "Disabling a plugin"
    check:
      togglePlugin(db, initLimitedString(capacity = 9, "disable 1"), true,
          commands) == QuitSuccess
    checkpoint "Enabling a plugin"
    check:
      togglePlugin(db, initLimitedString(capacity = 8, "enable 1"), false,
          commands) == QuitSuccess
    checkpoint "Enabling an enabled plugin"
    check:
      togglePlugin(db, initLimitedString(capacity = 8, "enable 2"), false,
          commands) == QuitFailure

  test "Uninstalling a plugin":
    checkpoint "Uninstalling an installed plugin"
    check:
      removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
          commands) == QuitSuccess
    checkpoint "Uninstalling a non-installed plugin"
    check:
      removePlugin(db, initLimitedString(capacity = 8, "remove 1"),
          commands) == QuitFailure

  test "Initializing an object of Plugin type":
    let newPlugin = newPlugin(path = "/")
    check:
      newPlugin.location == "/"

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
