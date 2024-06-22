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

## Provides unit tests for options module

import std/paths
import utils/utils
import ../src/history
import unittest2
include ../src/options

suite "Unit tests for options module":

  checkpoint "Initializing the tests"
  const dbName: Path = "test11.db".Path
  let db: DbConn = initDb(dbName = dbName)
  var commands: ref Table[string, CommandData] = newTable[string, CommandData]()
  discard initHistory(db = db, commands = commands)

  test "Initializiation of the shell's options":
    initOptions(commands = commands, db = db)
    check:
      commands.len > 0

  test "Getting the value of an existing option":
    check:
      getOption(optionName = "historyLength", db = db).len > 0

  test "Getting the value of a non-existing option":
    check:
      getOption(optionName = "werweewfwe", db = db).len == 0

  test "Adding a new option":
    const optionName: OptionName = "testOption"
    setOption(optionName = optionName, value = "200", db = db)
    check:
      deleteOption(optionName = optionName, db = db) == QuitSuccess
      getOption(optionName = optionName, db = db).len == 0

  test "Updating an existing option":
    setOption(optionName = "historyLength", value = "100", db = db)
    check:
      getOption(optionName = "historyLength", db = db) == "100"

  test "Setting the new value for an option":
    when defined(testInput):
      check:
        setOptions(db = db) == QuitSuccess
        getOption(optionName = "colorSyntax", db = db) == "true"
    else:
      skip()

  test "Resetting the shell's options":
    check:
      resetOptions(arguments = "reset all", db = db) == QuitSuccess
      getOption(optionName = "historyLength", db = db) == "500"

  test "Showing all options":
    check:
      showOptions(db = db) == QuitSuccess

  test "Initializing an object of Option type":
    check:
      newOption(name = "newOpt").option == "newOpt"

  test "Getting the type of the database field for OptionValType":
    check:
      dbType(T = OptionValType) == "TEXT"

  test "Converting dbValue to OptionValType":
    check:
      dbValue(val = text).s == "text"

  test "Converting OptionValType to dbValue":
    check:
      to(dbVal = text.dbValue, T = OptionValType) == text

  suiteTeardown:
    removeDb(dbName = dbName, db = db)
