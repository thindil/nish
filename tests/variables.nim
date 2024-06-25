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

## Provides unit tests for variables module

import utils/utils
import unittest2
include ../src/variables

suite "Unit tests for variable modules":

  checkpoint "Initializing the tests"
  let db: DbConn = initDb()
  var commands: ref Table[string, CommandData] = newTable[string, CommandData]()

  initVariables(db = db, commands = commands)
  checkpoint "Adding testing variables if needed"
  if db.count(T = Variable) == 0:
    var variable: Variable = newVariable(name = "TESTS", path = "/".Path, recursive = true,
          value = "test_variable", description = "Test variable.")
    db.insert(obj = variable)
    var variable2: Variable = newVariable(name = "TESTS2", path = "/".Path,
        recursive = false, value = "test_variable2",
        description = "Test variable 2.")
    db.insert(obj = variable2)
  if db.count(T = Variable) == 1:
    var variable: Variable = newVariable(name = "TESTS2", path = "/".Path, recursive = false,
        value = "test_variable2", description = "Test variable 2.")
    db.insert(obj = variable)

  test "Building a SQL query":
    check:
      buildQuery(directory = "/".Path, fields = "name") ==
      "SELECT name FROM variables WHERE path='/' ORDER BY id ASC"

  test "Setting variables in the selected directory":
    setVariables(newDirectory = "/home".Path, db = db)

  test "Getting an environment variable":
    check:
      getEnv(key = "TESTS") == "test_variable"

  test "Checking do an environment variable exists":
    check:
      not existsEnv(key = "TESTS2")

  test "Getting ID of an existing variable":
    check:
      getVariableId(arguments = "delete 2", db = db).int == 2

  test "Getting ID of a non-existing variable":
    check:
      getVariableId(arguments = "delete 22", db = db).int == 0

  test "Showing available environment variables":
    check:
      listVariables(arguments = "list", db = db) ==
          QuitSuccess

  test "Showing all environment variables":
    check:
      listVariables(arguments = "list all", db = db) == QuitSuccess

  test "Showing environment variables with invalid subcommand":
    check:
      listVariables(arguments = "werwerew", db = db) == QuitSuccess

  test "Deleting a non-existing environment variable":
    check:
      deleteVariable(arguments = "delete 123", db = db) == QuitFailure

  test "Deleting a non-existing environment variable with invalid index":
    check:
      deleteVariable(arguments = "delete sdf", db = db) == QuitFailure

  test "Deleting an existing environment variable":
    check:
      deleteVariable(arguments = "delete 2", db = db) == QuitSuccess

  test "Deleting a previously deleted environment variable":
    check:
      deleteVariable(arguments = "delete 2", db = db) == QuitFailure

  test "Setting an evironment variable":
    check:
      setCommand(arguments = "test=test_val",
          db = db) ==
          QuitSuccess
      getEnv(key = "test") == "test_val"

  test "Unsetting an existing environment variable":
    check:
      unsetCommand(arguments = "test", db = db) ==
          QuitSuccess
      getEnv(key = "test") == ""

  test "Unsetting an non-existing environment variable":
    check:
      unsetCommand(arguments = "test", db = db) ==
          QuitSuccess

  test "Initializing an object of Variable type":
    let newVariable: Variable = newVariable(name = "ala")
    check:
      newVariable.name == "ala"

  test "Getting the type of the database field for VariableValType":
    check:
      dbType(T = VariableValType) == "TEXT"

  test "Converting dbValue to VariableValType":
    check:
      dbValue(val = text).s == "text"

  test "Converting VariableValType to dbValue":
    check:
      to(dbVal = text.dbValue, T = VariableValType) == text

  suiteTeardown:
    removeDb(db = db)
