# Copyright © 2022 Bartek Jasicki <thindil@laeran.pl>
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

import std/[db_sqlite, os, parseopt, strutils, tables]
import history, output

func initVariables*(helpContent: var Table[string, string]) {.gcsafe, locks: 0,
    raises: [], tags: [].} =
  ## Initialize enviroment variables. At this moment only set help related
  ## to the variables
  helpContent["set"] = """
        Usage set [name=value]

        Set the environment variable with the selected name and value.
          """
  helpContent["unset"] = """
        Usage unset [name]

        Remove the environment variable with the selected name.
          """

proc setCommand*(userInput: var OptParser; db: DbConn): int {.gcsafe,
    sideEffect, raises: [DbError, ValueError, IOError], tags: [ReadIOEffect,
    ReadDbEffect, WriteIOEffect, WriteDbEffect].} =
  ## Build-in command to set the selected environment variable
  userInput.next()
  if userInput.kind != cmdEnd:
    let varValues = userInput.key.split("=")
    if varValues.len() > 1:
      try:
        putEnv(varValues[0], varValues[1])
        showOutput("Environment variable '" & varValues[0] &
            "' set to '" & varValues[1] & "'", true)
        result = QuitSuccess
      except OSError:
        result = showError()
    else:
      result = showError("You have to enter the name of the variable and its value.")
  else:
    result = showError("You have to enter the name of the variable and its value.")
  discard updateHistory("set " & userInput.key, db, result)

proc unsetCommand*(userInput: var OptParser; db: DbConn): int {.gcsafe,
    sideEffect, raises: [DbError, ValueError, IOError], tags: [ReadIOEffect,
    ReadDbEffect, WriteIOEffect, WriteDbEffect].} =
  ## Build-in command to unset the selected environment variable
  userInput.next()
  if userInput.kind != cmdEnd:
    try:
      delEnv(userInput.key)
      showOutput("Environment variable '" & userInput.key & "' removed")
      result = QuitSuccess
    except OSError:
      result = showError()
  else:
    result = showError("You have to enter the name of the variable to unset.")
  discard updateHistory("unset " & userInput.key, db, result)
