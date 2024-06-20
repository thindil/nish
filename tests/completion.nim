# Copyright © 2024 Bartek Jasicki
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 1. Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# 3. Neither the name of the copyright holder nor the
# names of its contributors may be used to endorse or promote products
# derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY COPYRIGHT HOLDERS AND CONTRIBUTORS ''AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## Provides unit tests for completion module

import utils/utils
import ../src/[aliases, db]
import unittest2
{.hint[XDeclaredButNotUsed]: off.}
include ../src/completion

suite "Unit tests for completion module":

  checkpoint "Initializing the tests"
  let db: DbConn = initDb(dbName = "test5.db".Path)
  var
    myaliases: ref OrderedTable[string, int] = newOrderedTable[string, int]()
    commands: ref Table[string, CommandData] = newTable[string, CommandData]()
    completions: seq[string] = @[]

  checkpoint "Adding testing aliases if needed"
  db.addAliases
  initAliases(db = db, aliases = myaliases, commands = commands)

  checkpoint "Adding a test completion"
  if db.count(T = Completion) == 0:
    var completion: Completion = newCompletion(command = "ala", cType = custom,
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
    let newCompletion: Completion = newCompletion(command = "ala")
    check:
      newCompletion.command == "ala"

  test "Get completion for a command's argument":
    getCompletion(commandName = "ala", prefix = "some",
        completions = completions, aliases = myaliases, commands = commands, db = db)
    check:
      completions[0] == "something"

  test "Getting ID of an existing completion":
    check:
      getCompletionId(arguments = "delete 1",
          db = db).int == 1

  test "Getting ID of a non-existing completion":
    check:
      getCompletionId(arguments = "delete 22",
          db = db).int == 0

  test "Listing the defined commands' completions":
    check:
      listCompletion(arguments = "list", db = db) == QuitSuccess

  test "Deleting an existing completion":
    check:
      deleteCompletion(arguments = "delete 1",
          db = db) == QuitSuccess
      db.count(T = Completion) == 0
    var completion: Completion = newCompletion(command = "ala", cType = custom,
        cValues = "something")
    db.insert(obj = completion)

  test "Deleting a non-existing completion":
    check:
      deleteCompletion(arguments = "delete 2",
          db = db) == QuitFailure
      db.count(T = Completion) == 1

  test "Showing an existing completion":
    check:
      showCompletion(arguments = "show 1", db = db) == QuitSuccess

  test "Showing a non-existing completion":
    check:
      showCompletion(arguments = "show 2", db = db) == QuitFailure

  test "Exporting an existing completion":
    check:
      exportCompletion(arguments = "export 1 test.txt", db = db) == QuitSuccess

  test "Exporting a non-existing completion":
    check:
      exportCompletion(arguments = "export 2 test.txt", db = db) == QuitFailure

  test "Importing a new completion":
    discard deleteCompletion(arguments = "delete 1", db = db)
    check:
      importCompletion(arguments = "import test.txt", db = db) == QuitSuccess

  test "Importing an existing completion":
    check:
      importCompletion(arguments = "import test.txt", db = db) == QuitFailure

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
