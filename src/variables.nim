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

proc buildQuery(directory, fields: string): string {.gcsafe, sideEffect,
    raises: [], tags: [ReadDbEffect].} =
  ## Build database query for get environment variables for the selected
  ## directory
  result = "SELECT " & fields & " FROM variables WHERE path='" & directory & "'"
  var remainingDirectory: string = parentDir(directory)

# Construct SQL querry, search for variables also defined in parent directories
  # if they are recursive
  while remainingDirectory != "":
    result.add(" OR (path='" & remainingDirectory & "' AND recursive=1)")
    remainingDirectory = parentDir(remainingDirectory)

  result.add(" ORDER BY id ASC")

proc setVariables*(newDirectory: string; db: DbConn;
    oldDirectory: string = "") {.gcsafe, sideEffect, raises: [DbError, OSError],
    tags: [ReadDbEffect, WriteEnvEffect].} =
  ## Set the environment variables in the selected directory and remove the
  ## old ones

  # Remove the old environment variables if needed
  if oldDirectory.len() > 0:
    for dbResult in db.fastRows(sql(buildQuery(oldDirectory, "name"))):
      delEnv(dbResult[0])
  # Set the new environment variables
  for dbResult in db.fastRows(sql(buildQuery(newDirectory, "name, value"))):
    putEnv(dbResult[0], dbResult[1])

proc initVariables*(helpContent: var Table[string, string];
    db: DbConn) {.gcsafe, sideEffect, raises: [DbError, OSError], tags: [
    ReadDbEffect, WriteEnvEffect].} =
  ## Initialize enviroment variables. Set help related to the variables and
  ## load the local environment variables
  helpContent["set"] = """
        Usage set [name=value]

        Set the environment variable with the selected name and value.
          """
  helpContent["unset"] = """
        Usage unset [name]

        Remove the environment variable with the selected name.
          """
  helpContent["variable"] = """
        Usage: variable ?subcommand?

        If entered without subcommand, show the list of available subcommands
        for variables. Otherwise, execute the selected subcommand.
        """
  helpContent["variable list"] = """
        Usage: variable list ?all?

        Show the list of all declared in shell environment variables in
        the current directory. If parameter all added, show all declared
        environment variables.
        """
  setVariables(getCurrentDir(), db)

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

proc listVariables*(userInput: var OptParser; historyIndex: var int;
    db: DbConn) {.gcsafe, sideEffect, raises: [IOError, OSError, ValueError],
    tags: [ReadIOEffect, WriteIOEffect, ReadDbEffect, WriteDbEffect].} =
  ## List available variables, if entered command was "variables list all" list all
  ## declared variables then
  showOutput("Declared environent variables are:")
  showOutput("ID Name Value Description")
  userInput.next()
  if userInput.kind == cmdEnd:
    historyIndex = updateHistory("variable list", db)
    for row in db.fastRows(sql(buildQuery(getCurrentDir(),
        "id, name, value, description"))):
      showOutput(row[0] & " " & row[1] & " " & row[2] & " " & row[3])
  elif userInput.key == "all":
    historyIndex = updateHistory("variable list all", db)
    for row in db.fastRows(sql"SELECT id, name, value, description FROM variables"):
      showOutput(row[0] & " " & row[1] & " " & row[2] & " " & row[3])

proc helpVariables*(db: DbConn): int {.gcsafe, sideEffect, locks: 0, raises: [
    DbError, OSError, IOError, ValueError], tags: [ReadDbEffect, WriteDbEffect,
    ReadIOEffect, WriteIOEffect].} =
  ## Show short help about available subcommands related to the environment variables
  showOutput("""Available subcommands are: list

        To see more information about the subcommand, type help variable [command],
        for example: help variable list.
""")
  return updateHistory("variable", db)

