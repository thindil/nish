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

## Provides unit tests for help module

import std/tables
import utils/utils
import ../src/[aliases, db]
import unittest2
include ../src/help

suite "Unit tests for help module":

  checkpoint "Initializing the tests"
  let db = initDb(dbName = "test6.db")
  var commands = newTable[string, CommandData]()

  test "Initializing the help system":
    initHelp(db = db, commands = commands)
    check:
      commands.len == 2

  test "Adding a new help entry":
    discard deleteHelpEntry(topic = "test", db = db)
    checkpoint "Adding a non-existing help entry"
    check:
      addHelpEntry(topic = "test", usage = "test topic", plugin = "test",
          content = "test help", isTemplate = false, db = db) == QuitSuccess
    checkpoint "Adding an existing help entry"
    check:
      addHelpEntry(topic = "test", usage = "test topic", plugin = "test",
          content = "test help", isTemplate = false, db = db) == QuitFailure

  test "Deleting a help entry":
    discard deleteHelpEntry(topic = "test", db = db)
    check:
      addHelpEntry(topic = "test", usage = "test topic", plugin = "test",
          content = "test help", isTemplate = false, db = db) == QuitSuccess
    checkpoint "Deleting an existing help entry"
    check:
      deleteHelpEntry(topic = "test", db = db) ==
          QuitSuccess
    checkpoint "Deleting a non-existing help entry"
    check:
      deleteHelpEntry(topic = "asdd", db = db) ==
          QuitFailure
    checkpoint "Deleting a deleted help entry"
    check:
      deleteHelpEntry(topic = "test", db = db) ==
          QuitFailure

  test "Updating the help system":
    check:
      updateHelp(db = db) == QuitSuccess

  test "Loading the help content from a file":
    db.exec(query = "DELETE FROM help".sql)
    checkpoint "Loading the help content to the empty help system"
    check:
      readHelpFromFile(db = db) == QuitSuccess
    checkpoint "Loading the help content to the full help system"
    check:
      readHelpFromFile(db = db) == QuitFailure

  test "Showing the help entry":
    checkpoint "Showing an existing help entry"
    check:
      showHelp(topic = "alias", db = db) ==
          QuitSuccess
    checkpoint "Showing a non-existing help entry"
    check:
      showHelp(topic = "srewfdsfs", db = db) ==
          QuitFailure

  test "Showing list of help for a command":
    check:
      showHelpList(command = "alias", subcommands = aliasesCommands, db = db) == QuitSuccess

  test "Showing the unknown help entry screen":
    check:
      showUnknownHelp(subCommand = "command", command = "subcommand",
          helpType = "helptype", db = db) == QuitFailure

  test "Updating a help entry":
    discard deleteHelpEntry(topic = "test", db = db)
    unittest2.require:
      addHelpEntry(topic = "test", usage = "test topic", plugin = "test",
          content = "test help", isTemplate = false, db = db) == QuitSuccess
    checkpoint "Updating an existing help entry"
    check:
      updateHelpEntry(topic = "test", usage = "test topic", plugin = "test",
          content = "test help2", db = db, isTemplate = false) == QuitSuccess
    checkpoint "Updating a non-existing help entry"
    check:
      updateHelpEntry(topic = "asdd", usage = "test topic", plugin = "test",
          content = "test help2", db = db, isTemplate = false) == QuitFailure

  test "Initializing an object of HelpEntry type":
    let newHelp = newHelpEntry(topic = "test")
    check:
      newHelp.topic == "test"

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
