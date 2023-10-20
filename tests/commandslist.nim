import std/[strutils, tables]
import ../src/[aliases, commandslist, constants, db, directorypath, lstring, resultcode]
import contracts, unittest2
import norm/sqlite

suite "Unit tests for commandslist module":

  checkpoint "Initializing the tests"
  let db = startDb("test4.db".DirectoryPath)
  unittest2.require:
    db != nil

  checkpoint "Adding testing aliases if needed"
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

  test "Adding a new command":
    checkpoint "Adding a new command"
    addCommand(name = initLimitedString(capacity = 4, text = "test"),
        command = testCommand, commands = commands)
    check:
      commands.len == 1
    checkpoint "Readding the same command"
    expect CommandsListError:
      addCommand(name = initLimitedString(capacity = 4, text = "test"),
          command = testCommand, commands = commands)
    check:
      commands.len == 1
    checkpoint "Overwritting built-in command"
    expect CommandsListError:
      addCommand(name = initLimitedString(capacity = 4, text = "exit"),
          command = testCommand, commands = commands)
    check:
      commands.len == 1

  test "Replacing a command":
    checkpoint "Replacing an existing command"
    replaceCommand(name = initLimitedString(capacity = 4, text = "test"),
        command = testCommand2, commands = commands)
    checkpoint "Replacing a built-in command"
    expect CommandsListError:
      replaceCommand(name = initLimitedString(capacity = 4, text = "exit"),
          command = testCommand, commands = commands)

  test "Deleting a command":
    checkpoint "Deleting an exisiting command"
    deleteCommand(name = initLimitedString(capacity = 4, text = "test"),
        commands = commands)
    check:
      commands.len == 0
    addCommand(name = initLimitedString(capacity = 5, text = "test2"),
        command = testCommand, commands = commands)
    unittest2.require:
      commands.len == 1
    checkpoint "Deleting a non-existing command"
    expect CommandsListError:
      deleteCommand(name = initLimitedString(capacity = 4, text = "test"),
          commands = commands)
    check:
      commands.len == 1

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
