import utils/utils
import ../src/[aliases, db]
import unittest2
{.warning[UnusedImport]:off.}
{.hint[XDeclaredButNotUsed]:off.}
include ../src/completion

suite "Unit tests for completion module":

  checkpoint "Initializing the tests"
  let db = initDb("test5.db")
  var
    myaliases = newOrderedTable[string, int]()
    commands = newTable[string, CommandData]()
    completions: seq[string]

  checkpoint "Adding testing aliases if needed"
  db.addAliases
  initAliases(db, myaliases, commands)

  checkpoint "Adding a test completion"
  if db.count(Completion) == 0:
    var completion = newCompletion(command = "ala", cType = custom,
        cValues = "something")
    db.insert(completion)

  test "Get completion for a file name":
    open("sometest.txt", fmWrite).close
    getDirCompletion("somete", completions, db)
    removeFile("sometest.txt")
    check:
      completions == @["sometest.txt"]

  test "Get completion for a command":
    getCommandCompletion("exi", completions, myaliases, commands, db)
    check:
      completions[1] == "exit"

  test "Initializing an object of Completion type":
    let newCompletion = newCompletion(command = "ala")
    check:
      newCompletion.command == "ala"

  test "Get completion for a command's argument":
    getCompletion("ala", "some", completions, myaliases, commands, db)
    check:
      completions[0] == "something"

  test "Getting the shell's completion ID":
    checkpoint "Getting ID of an existing completion"
    check:
      getCompletionId("delete 1",
          db).int == 1
    checkpoint "Getting ID of a non-existing completion"
    check:
      getCompletionId("delete 22",
          db).int == 0

  test "Listing the defined commands' completions":
    check:
      listCompletion("list", db) == QuitSuccess

  test "Deleting a command's completion":
    checkpoint "Deleting an existing completion"
    check:
      deleteCompletion("delete 1",
          db) == QuitSuccess
      db.count(Completion) == 0
    var completion = newCompletion(command = "ala", cType = custom,
        cValues = "something")
    db.insert(completion)
    checkpoint "Deleting a non-existing completion"
    check:
      deleteCompletion("delete 2",
          db) == QuitFailure
      db.count(Completion) == 1

  test "Show a command's completion":
    checkpoint "Showing an existing completion"
    check:
      showCompletion("show 1", db) == QuitSuccess
    checkpoint "Showing a non-existing completion"
    check:
      showCompletion("show 2", db) == QuitFailure

  test "Exporting a command's completion":
    checkpoint "Exporting an existing completion"
    check:
      exportCompletion("export 1 test.txt", db) == QuitSuccess
    checkpoint "Exporting a non-existing completion"
    check:
      exportCompletion("export 2 test.txt", db) == QuitFailure

  test "Importing a command's completion":
    checkpoint "Importing a new completion"
    discard deleteCompletion("delete 1", db)
    check:
      importCompletion("import test.txt", db) == QuitSuccess
    checkpoint "Importing an existing completion"
    check:
      importCompletion("import test.txt", db) == QuitFailure

  suiteTeardown:
    closeDb(QuitSuccess.ResultCode, db)
