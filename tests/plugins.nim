import std/tables
import utils/utils
import ../src/[commandslist, db, plugins, resultcode]
import unittest2

suite "Unit tests for plugins module":

  checkpoint "Initializing the tests"
  let db = initDb("test13.db")
  var commands = newTable[string, CommandData]()

  test "Initialization of plugins":
    initPlugins(db, commands)

  test "Adding a new plugin":
    discard removePlugin(db, "remove 1", commands)
    checkpoint "Adding an existing, not added plugin"
    check:
      addPlugin(db,
          "add tools/testplugin.sh", commands) == QuitSuccess
    checkpoint "Adding an existing, previously added plugin"
    check:
      addPlugin(db,
          "add tools/testplugin.sh", commands) == QuitFailure
    checkpoint "Adding a non-existing plugin"
    check:
      addPlugin(db,
          "add tools/testplugin.223sh", commands) == QuitFailure

  test "Getting the plugin's ID":
    checkpoint "Getting ID of an existing plugin"
    check:
      getPluginId("remove 1", db).int == 1
    checkpoint "Getting ID of a non-existing plugin"
    check:
      getPluginId("remove 22", db).int == 0

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
      listPlugins("list", db) ==
          QuitSuccess
    checkpoint "Showing all plugins"
    check:
      listPlugins("list all", db) ==
          QuitSuccess
    checkpoint "Showing enabled plugins with invalid subcommand"
    check:
      listPlugins("list werwerew",
          db) == QuitSuccess

  test "Enabling or disabling a plugin":
    checkpoint "Disabling a plugin"
    check:
      togglePlugin(db, "disable 1", true,
          commands) == QuitSuccess
    checkpoint "Enabling a plugin"
    check:
      togglePlugin(db, "enable 1", false,
          commands) == QuitSuccess
    checkpoint "Enabling an enabled plugin"
    check:
      togglePlugin(db, "enable 2", false,
          commands) == QuitFailure

  test "Uninstalling a plugin":
    checkpoint "Uninstalling an installed plugin"
    check:
      removePlugin(db, "remove 1",
          commands) == QuitSuccess
    checkpoint "Uninstalling a non-installed plugin"
    check:
      removePlugin(db, "remove 1",
          commands) == QuitFailure

  test "Initializing an object of Plugin type":
    let newPlugin = newPlugin(path = "/")
    check:
      newPlugin.location == "/"

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
