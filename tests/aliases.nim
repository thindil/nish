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

## Provides unit tests for aliases module

import utils/utils
import unittest2
import ../src/db
include ../src/aliases

suite "Unit tests for aliases module":

  checkpoint "Initializing the tests"
  let db: DbConn = initDb(dbName = "test2.db")
  var
    myaliases: ref OrderedTable[string, int] = newOrderedTable[string, int]()
    commands: ref Table[string, CommandData] = newTable[string, CommandData]()

  checkpoint "Adding testing aliases if needed"
  db.addAliases

  test "Initialization of the shell's aliases":
    initAliases(db = db, aliases = myaliases, commands = commands)
    check:
      myaliases.len == 1

  test "Getting ID of an existing alias":
    check:
      getAliasId(arguments = "delete 2", db = db).int == 2

  test "Getting ID of a non-existing alias":
    check:
      getAliasId(arguments = "delete 22", db = db).int == 0

  test "Deleting an existing alias":
    check:
      deleteAlias(arguments = "delete 2", aliases = myaliases, db = db) == QuitSuccess
      db.count(T = Alias) == 1

  test "Deleting a non-existing alias":
    check:
      deleteAlias(arguments = "delete 22", aliases = myaliases, db = db) == QuitFailure

  test "Re-adding the test alias":
    var testAlias2: Alias = newAlias(name = "tests2", path = "/".Path,
      recursive = false,
      commands = "ls -a", description = "Test alias 2.", output = "output")
    db.insert(obj = testAlias2)
    unittest2.require:
      db.count(T = Alias) == 2

  test "Checking an existing alias":
    myaliases.setAliases(directory = paths.getCurrentDir(), db = db)
    check:
      execAlias(arguments = "", aliasId = "tests", aliases = myaliases,
          db = db) == QuitSuccess

  test "Checking a non existing alias":
    check:
      execAlias(arguments = "", aliasId = "tests2", aliases = myaliases,
          db = db) == QuitFailure

  test "List the shell's aliases in the current directory":
    check:
      db.count(T = Alias) == 2
      listAliases(arguments = "list", aliases = myaliases, db = db) == QuitSuccess

  test "List all available the shell aliases":
    check:
      listAliases(arguments = "list all", aliases = myaliases, db = db) == QuitSuccess

  test "Check what happen when invalid argument passed to listAliases":
    expect PreConditionDefect:
      check:
        listAliases(arguments = "werwerew", aliases = myaliases, db = db) == QuitSuccess

  test "Initializing an object of Alias type":
    let newAlias: Alias = newAlias(name = "ala")
    check:
      newAlias.name == "ala"

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
