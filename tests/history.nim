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

## Provides unit tests for history module

import std/tables
import utils/utils
import ../src/db
import unittest2
include ../src/history

suite "Unit tests for history module":

  checkpoint "Initializing the tests"
  let db: DbConn = initDb(dbName = "test8.db")
  var commands: ref Table[string, CommandData] = newTable[string, CommandData]()

  checkpoint "Initializing the shell's history"
  var amount: HistoryRange = initHistory(db = db, commands = commands)
  if amount == 0:
    discard updateHistory(commandToAdd = "alias delete", db = db)

  test "Getting the shell's history entry":
    check:
      getHistory(historyIndex = 1, db = db) == "alias delete"

  test "Getting the shell's history length":
    amount = historyLength(db = db)
    check:
      updateHistory(commandToAdd = "test comm", db = db) == amount + 1

  test "Showing the shell's history":
    check:
     showHistory(db = db, arguments = "list") ==
      QuitSuccess

  test "Finding an exising entry in the history":
    check:
      findInHistory(db = db, arguments = "find te") ==
           QuitSuccess

  test "Finding a non-exising entry in the history":
    check:
      findInHistory(db = db, arguments = "find asd") == QuitFailure

  test "Clearing the shell's history":
    check:
      clearHistory(db = db) == 0
      historyLength(db = db) == 0

  test "Initializing an object of HistoryEntry type":
    check:
      newHistoryEntry(command = "newCom").command == "newCom"

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
