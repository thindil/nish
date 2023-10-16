import std/[strutils, tables]
import ../src/[aliases, commandslist, constants, db, directorypath, lstring, resultcode]
import contracts, unittest2
import norm/sqlite

suite "Unit tests for commandslist module":

  let db = startDb("test4.db".DirectoryPath)
  assert db != nil, "Failed to initialized database."
  if db.count(Alias) == 0:
    var alias = newAlias(name = "tests", path = "/", recursive = true,
        commands = "ls -a", description = "Test alias.", output = "output")
    db.insert(alias)
    var testAlias2 = newAlias(name = "tests2", path = "/", recursive = false,
        commands = "ls -a", description = "Test alias 2.", output = "output")
    db.insert(testAlias2)
  var
    commands = newTable[string, CommandData]()

  proc testCommand(arguments: UserInput; db: DbConn;
      list: CommandLists): ResultCode {.gcsafe, raises: [], contractual.} =
    body:
      echo "test"

  proc testCommand2(arguments: UserInput; db: DbConn;
      list: CommandLists): ResultCode {.gcsafe, raises: [], contractual.} =
    body:
      echo "test2"

  test "addCommand":
    addCommand(name = initLimitedString(capacity = 4, text = "test"),
        command = testCommand, commands = commands)
    check:
      commands.len == 1
    try:
      addCommand(name = initLimitedString(capacity = 4, text = "test"),
          command = testCommand, commands = commands)
    except CommandsListError:
      discard
    check:
      commands.len == 1
    try:
      addCommand(name = initLimitedString(capacity = 4, text = "exit"),
          command = testCommand, commands = commands)
    except CommandsListError:
      discard
    check:
      commands.len == 1

  test "replaceCommand":
    replaceCommand(name = initLimitedString(capacity = 4, text = "test"),
        command = testCommand2, commands = commands)
    try:
      replaceCommand(name = initLimitedString(capacity = 4, text = "exit"),
          command = testCommand, commands = commands)
    except CommandsListError:
      discard

  test "deleteCommand":
    deleteCommand(name = initLimitedString(capacity = 4, text = "test"),
        commands = commands)
    check:
      commands.len == 0
    addCommand(name = initLimitedString(capacity = 5, text = "test2"),
        command = testCommand, commands = commands)
    unittest2.require:
      commands.len == 1
    try:
      deleteCommand(name = initLimitedString(capacity = 4, text = "test"),
          commands = commands)
    except CommandsListError:
      discard
    check:
      commands.len == 1

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
