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

## Provides unit tests for output module

when defined(testInput):
  import std/tables
import utils/utils
import ../src/db
import unittest2
include ../src/output

suite "Unit tests for output module":

  checkpoint "Initializing the tests"
  let db: DbConn = initDb(dbName = "test12.db")

  test "Showing an error message":
    check:
      showError(message = "test error", db = db) == QuitFailure

  test "Drawing a form's header":
    showFormHeader(message = "test header", db = db)

  test "Showing a normal output":
    showOutput(message = "test output", db = db)

  test "Showing options to select":
    when defined(testInput):
      check:
        selectOption(options = {'a': "option1", 'b': "option2"}.toTable,
            default = 'a', prompt = "Option", db = db) == 'a'
    else:
      skip()

  test "Showing confirmation prompt":
    when defined(testInput):
      check:
        confirm(prompt = "Confirm", db = db)
    else:
      skip()

  test "Showing a form's prompt":
    showFormPrompt(prompt = "Form prompt", db = db)

  suiteTeardown:
    closeDb(returnCode = QuitSuccess.ResultCode, db = db)
