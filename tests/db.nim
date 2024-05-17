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

## Provides unit tests for db module

import std/tables
import utils/utils
import unittest2
include ../src/db

suite "Unit tests for db module":

  checkpoint "Initializing the tests"
  let db: DbConn = initDb(dbName = "test15.db")
  var commands: ref Table[string, CommandData] = newTable[string, CommandData]()

  test "Initialization of the shell's database's commands":
    initDb(db = db, commands = commands)
    check:
      commands.len == 1

  test "Optimizing the shell's database":
    check:
      optimizeDb(arguments = "optimize", db = db) == QuitSuccess

  test "Exporting the shell's database":
    check:
      exportDb(arguments = "export test.txt", db = db) == QuitSuccess

  test "Importing the shell's database":
    db.exec(query = "DROP TABLE help".sql)
    db.exec(query = "DROP TABLE options".sql)
    db.exec(query = "DROP TABLE theme".sql)
    check:
      importDb(arguments = "import test.txt", db = db) == QuitSuccess

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
