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

## Provides unit tests for commandslist module

import utils/utils
import ../src/db
import unittest2
include ../src/commandslist

suite "Unit tests for commandslist module":

  checkpoint "Initializing the tests"
  let db: DbConn = initDb(dbName = "test4.db")

  checkpoint "Adding testing aliases if needed"
  db.addAliases
  var commands: ref Table[string, CommandData] = newTable[string, CommandData]()

  {.push ruleOff: "params".}
  proc testCommand(arguments: UserInput; db: DbConn;
      list: CommandLists): ResultCode {.gcsafe, raises: [], tags: [],
      contractual.} =
    ## Dummy command for tests
    body:
      echo "test"

  proc testCommand2(arguments: UserInput; db: DbConn;
      list: CommandLists): ResultCode {.gcsafe, raises: [], tags: [],
      contractual.} =
    ## Dummy command for tests
    body:
      echo "test2"
  {.push ruleOn: "params".}

  test "Adding a new command":
    addCommand(name = "test",
        command = testCommand, commands = commands)
    check:
      commands.len == 1

  test "Readding the same command":
    expect CommandsListError:
      addCommand(name = "test",
          command = testCommand, commands = commands)
    check:
      commands.len == 1

  test "Overwritting built-in command":
    expect CommandsListError:
      addCommand(name = "exit",
          command = testCommand, commands = commands)
    check:
      commands.len == 1

  test "Replacing an existing command":
    replaceCommand(name = "test",
        command = testCommand2, commands = commands, db = db)

  test "Replacing a built-in command":
    expect CommandsListError:
      replaceCommand(name = "exit",
          command = testCommand, commands = commands, db = db)

  test "Deleting an exisiting command":
    deleteCommand(name = "test",
        commands = commands)
    check:
      commands.len == 0
    addCommand(name = "test2",
        command = testCommand, commands = commands)
    unittest2.require:
      commands.len == 1

  test "Deleting a non-existing command":
    expect CommandsListError:
      deleteCommand(name = "test",
          commands = commands)
    check:
      commands.len == 1

  test "Execute a command inside the system's default shell":
    check:
      runCommand(commandName = "ls", arguments = "-a .", withShell = true,
          db = db) == QuitSuccess

  test "Execute a command without the system's default shell":
    check:
      runCommand(commandName = "ls", arguments = "-a .", withShell = false,
          db = db) == QuitSuccess

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
