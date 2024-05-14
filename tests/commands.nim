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

## Provides unit tests for commands module

import utils/utils
import unittest2
import ../src/db
include ../src/commands

suite "Unit tests for commands module":

  checkpoint "Initializing the tests"
  let db: DbConn = initDb(dbName = "test3.db")

  checkpoint "Adding testing aliases if needed"
  db.addAliases
  var myaliases: ref OrderedTable[string, int] = newOrderedTable[string, int]()

  test "Testing cd command":
    checkpoint "Entering an existing directory"
    check:
      cdCommand(newDirectory = "/".Path, aliases = myaliases, db = db) == QuitSuccess
    checkpoint "Trying to enter a non-existing directory"
    check:
      cdCommand(newDirectory = "/adfwerewtr".Path, aliases = myaliases,
          db = db) == QuitFailure

  test "Testing changing the current directory of the shell":
    checkpoint "Changing the current directory"
    check:
      changeDirectory(newDirectory = "..".Path, aliases = myaliases, db = db) == QuitSuccess
    checkpoint "Changing the current directory to non-existing directory"
    check:
      changeDirectory(newDirectory = "/adfwerewtr".Path, aliases = myaliases,
          db = db) == QuitFailure

  test "Executing a command":
    var
      cursorPosition: Natural = 1
      commands: ref Table[string, CommandData] = newTable[string, CommandData]()
    check:
      executeCommand(commands = commands, commandName = "ls",
          arguments = "-a .", inputString = "ls -a .", db = db,

aliases = myaliases, cursorPosition = cursorPosition) == QuitSuccess

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
