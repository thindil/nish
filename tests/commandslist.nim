import utils/utils
import ../src/db
import unittest2
{.warning[UnusedImport]:off.}
include ../src/commandslist

suite "Unit tests for commandslist module":

  checkpoint "Initializing the tests"
  let db = initDb("test4.db")

  checkpoint "Adding testing aliases if needed"
  db.addAliases
  var commands = newTable[string, CommandData]()

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
    addCommand(name = "test",
        command = testCommand, commands = commands)
    check:
      commands.len == 1
    checkpoint "Readding the same command"
    expect CommandsListError:
      addCommand(name = "test",
          command = testCommand, commands = commands)
    check:
      commands.len == 1
    checkpoint "Overwritting built-in command"
    expect CommandsListError:
      addCommand(name = "exit",
          command = testCommand, commands = commands)
    check:
      commands.len == 1

  test "Replacing a command":
    checkpoint "Replacing an existing command"
    replaceCommand(name = "test",
        command = testCommand2, commands = commands, db = db)
    checkpoint "Replacing a built-in command"
    expect CommandsListError:
      replaceCommand(name = "exit",
          command = testCommand, commands = commands, db = db)

  test "Deleting a command":
    checkpoint "Deleting an exisiting command"
    deleteCommand(name = "test",
        commands = commands)
    check:
      commands.len == 0
    addCommand(name = "test2",
        command = testCommand, commands = commands)
    unittest2.require:
      commands.len == 1
    checkpoint "Deleting a non-existing command"
    expect CommandsListError:
      deleteCommand(name = "test",
          commands = commands)
    check:
      commands.len == 1

  test "Executing a command":
    checkpoint "Execute a command inside the system's default shell"
    check:
      runCommand("ls", "-a .", true, db) == QuitSuccess
    checkpoint "Execute a command without the system's default shell"
    check:
      runCommand("ls", "-a .", false, db) == QuitSuccess

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
