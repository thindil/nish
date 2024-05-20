import utils/utils
import ../src/[aliases, db]
import unittest2
{.warning[UnusedImport]: off.}
{.hint[XDeclaredButNotUsed]: off.}
include ../src/completion

suite "Unit tests for completion module":

  checkpoint "Initializing the tests"
  let db = initDb(dbName = "test5.db")
  var
    myaliases = newOrderedTable[string, int]()
    commands = newTable[string, CommandData]()
    completions: seq[string]

  checkpoint "Adding testing aliases if needed"
  db.addAliases
  initAliases(db = db, aliases = myaliases, commands = commands)

  checkpoint "Adding a test completion"
  if db.count(T = Completion) == 0:
    var completion = newCompletion(command = "ala", cType = custom,
        cValues = "something")
    db.insert(obj = completion)

  test "Get completion for a file name":
    open(filename = "sometest.txt", mode = fmWrite).close
    getDirCompletion(prefix = "somete", completions = completions, db = db)
    removeFile(file = "sometest.txt")
    check:
      completions == @["sometest.txt"]

  test "Get completion for a command":
    getCommandCompletion(prefix = "exi", completions = completions,
        aliases = myaliases, commands = commands, db = db)
    check:
      completions[1] == "exit"

  test "Initializing an object of Completion type":
    let newCompletion = newCompletion(command = "ala")
    check:
      newCompletion.command == "ala"

  test "Get completion for a command's argument":
    getCompletion(commandName = "ala", prefix = "some",
        completions = completions, aliases = myaliases, commands = commands, db = db)
    check:
      completions[0] == "something"

  test "Getting the shell's completion ID":
    checkpoint "Getting ID of an existing completion"
    check:
      getCompletionId(arguments = "delete 1",
          db = db).int == 1
    checkpoint "Getting ID of a non-existing completion"
    check:
      getCompletionId(arguments = "delete 22",
          db = db).int == 0

  test "Listing the defined commands' completions":
    check:
      listCompletion(arguments = "list", db = db) == QuitSuccess

  test "Deleting a command's completion":
    checkpoint "Deleting an existing completion"
    check:
      deleteCompletion(arguments = "delete 1",
          db = db) == QuitSuccess
      db.count(T = Completion) == 0
    var completion = newCompletion(command = "ala", cType = custom,
        cValues = "something")
    db.insert(obj = completion)
    checkpoint "Deleting a non-existing completion"
    check:
      deleteCompletion(arguments = "delete 2",
          db = db) == QuitFailure
      db.count(T = Completion) == 1

  test "Show a command's completion":
    checkpoint "Showing an existing completion"
    check:
      showCompletion(arguments = "show 1", db = db) == QuitSuccess
    checkpoint "Showing a non-existing completion"
    check:
      showCompletion(arguments = "show 2", db = db) == QuitFailure

  test "Exporting a command's completion":
    checkpoint "Exporting an existing completion"
    check:
      exportCompletion(arguments = "export 1 test.txt", db = db) == QuitSuccess
    checkpoint "Exporting a non-existing completion"
    check:
      exportCompletion(arguments = "export 2 test.txt", db = db) == QuitFailure

  test "Importing a command's completion":
    checkpoint "Importing a new completion"
    discard deleteCompletion(arguments = "delete 1", db = db)
    check:
      importCompletion(arguments = "import test.txt", db = db) == QuitSuccess
    checkpoint "Importing an existing completion"
    check:
      importCompletion(arguments = "import test.txt", db = db) == QuitFailure

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
