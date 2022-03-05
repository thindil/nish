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

import std/[db_sqlite, os, strutils, tables, terminal]
import constants, history, input, output

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

proc initVariables*(helpContent: var HelpTable;
    db: DbConn) {.gcsafe, sideEffect, raises: [DbError, OSError], tags: [
    ReadDbEffect, WriteEnvEffect].} =
  ## Initialize enviroment variables. Set help related to the variables and
  ## load the local environment variables
  helpContent["set"] = HelpEntry(usage: "set [name=value]",
      content: "Set the environment variable with the selected name and value.")
  helpContent["unset"] = HelpEntry(usage: "unset [name]",
      content: "Remove the environment variable with the selected name.")
  helpContent["variable"] = HelpEntry(usage: "variable ?subcommand?",
      content: "If entered without subcommand, show the list of available subcommands for variables. Otherwise, execute the selected subcommand.")
  helpContent["variable list"] = HelpEntry(usage: "variable list ?all?",
      content: "Show the list of all declared in shell environment variables in the current directory. If parameter all added, show all declared environment variables.")
  helpContent["variable delete"] = HelpEntry(usage: "variable delete [index]",
      content: "Delete the declared in shell environment variable with the selected index.")
  helpContent["variable add"] = HelpEntry(usage: "variable add",
      content: "Start adding a new variable to the shell. You will be able to set its name, description, value, etc.")
  helpContent["variable edit"] = HelpEntry(usage: "variable edit [index]",
      content: "Start editing the variable with the selected index. You will be able to set again its all parameters.")
  setVariables(getCurrentDir(), db)

proc setCommand*(arguments: string; db: DbConn): int {.gcsafe,
    sideEffect, raises: [DbError, ValueError, IOError], tags: [ReadIOEffect,
    ReadDbEffect, WriteIOEffect, WriteDbEffect].} =
  ## Build-in command to set the selected environment variable
  if arguments.len() > 0:
    let varValues = arguments.split("=")
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
  discard updateHistory("set " & arguments, db, result)

proc unsetCommand*(arguments: string; db: DbConn): int {.gcsafe,
    sideEffect, raises: [DbError, ValueError, IOError], tags: [ReadIOEffect,
    ReadDbEffect, WriteIOEffect, WriteDbEffect].} =
  ## Build-in command to unset the selected environment variable
  if arguments.len() > 0:
    try:
      delEnv(arguments)
      showOutput("Environment variable '" & arguments & "' removed")
      result = QuitSuccess
    except OSError:
      result = showError()
  else:
    result = showError("You have to enter the name of the variable to unset.")
  discard updateHistory("unset " & arguments, db, result)

proc listVariables*(arguments: string; historyIndex: var int;
    db: DbConn) {.gcsafe, sideEffect, raises: [IOError, OSError, ValueError],
    tags: [ReadIOEffect, WriteIOEffect, ReadDbEffect, WriteDbEffect].} =
  ## List available variables, if entered command was "variables list all" list all
  ## declared variables then
  showOutput("Declared environent variables are:")
  showOutput("ID Name Value Description")
  if arguments == "list":
    for row in db.fastRows(sql(buildQuery(getCurrentDir(),
        "id, name, value, description"))):
      showOutput(row[0] & " " & row[1] & " " & row[2] & " " & row[3])
  elif arguments == "list all":
    for row in db.fastRows(sql"SELECT id, name, value, description FROM variables"):
      showOutput(row[0] & " " & row[1] & " " & row[2] & " " & row[3])
  historyIndex = updateHistory("variable " & arguments, db)

proc helpVariables*(db: DbConn): int {.gcsafe, sideEffect, locks: 0, raises: [
    DbError, OSError, IOError, ValueError], tags: [ReadDbEffect, WriteDbEffect,
    ReadIOEffect, WriteIOEffect].} =
  ## Show short help about available subcommands related to the environment variables
  showOutput("""Available subcommands are: list, delete, add, edit

        To see more information about the subcommand, type help variable [command],
        for example: help variable list.
""")
  return updateHistory("variable", db)

proc deleteVariable*(arguments: string; historyIndex: var int;
    db: DbConn): int {.gcsafe, sideEffect, raises: [IOError, ValueError,
    OSError], tags: [WriteIOEffect, ReadIOEffect, ReadDbEffect,
    WriteDbEffect].} =
  ## Delete the selected variable from the shell's database
  if arguments.len() < 8:
    historyIndex = updateHistory("variable delete", db, QuitFailure)
    return showError("Enter the Id of the variable to delete.")
  let varName = arguments[7 .. ^1]
  if db.execAffectedRows(sql"DELETE FROM variables WHERE id=?",
      varName) == 0:
    historyIndex = updateHistory("variable delete", db, QuitFailure)
    return showError("The variable with the Id: " & varName &
      " doesn't exist.")
  historyIndex = updateHistory("variable delete", db)
  setVariables(getCurrentDir(), db, getCurrentDir())
  showOutput("Deleted the variable with Id: " & varName)
  return QuitSuccess

proc addVariable*(historyIndex: var int; db: DbConn): int {.gcsafe, sideEffect,
    raises: [EOFError, OSError, IOError, ValueError], tags: [ReadDbEffect,
    ReadIOEffect, WriteIOEffect, WriteDbEffect].} =
  ## Add a new variable to the shell. Ask the user a few questions and fill the
  ## variable values with answers
  showOutput("You can cancel adding a new variable at any time by double press Escape key.")
  showOutput(message = "#####################", fgColor = fgYellow)
  showOutput(message = "(1/5) Name", fgColor = fgYellow)
  showOutput(message = "#####################", fgColor = fgYellow)
  showOutput("The name of the variable. For example: 'MY_KEY'.:")
  var name = ""
  showOutput("Name: ", false)
  while name.len() == 0:
    name = readInput(aliasNameLength)
    if name.len() == 0:
      discard showError("Please enter a name for the variable.")
    elif not name.validIdentifier:
      name = ""
      discard showError("Please enter a valid name for the variable.")
    if name.len() == 0:
      showOutput("Name: ", false)
  if name == "exit":
    return showError("Adding a new variable cancelled.")
  showOutput(message = "#####################", fgColor = fgYellow)
  showOutput(message = "(2/5) Description", fgColor = fgYellow)
  showOutput(message = "#####################", fgColor = fgYellow)
  showOutput("The description of the variable. It will be show on the list of available variables. For example: 'My key to database.'. Can't contains a new line character.: ")
  showOutput("Description: ", false)
  let description = readInput()
  if description == "exit":
    return showError("Adding a new variable cancelled.")
  showOutput(message = "#####################", fgColor = fgYellow)
  showOutput(message = "(3/5) Working directory", fgColor = fgYellow)
  showOutput(message = "#####################", fgColor = fgYellow)
  showOutput("The full path to the directory in which the variable will be available. If you want to have a global variable, set it to '/'.: ")
  showOutput("Path: ", false)
  var path = ""
  while path.len() == 0:
    path = readInput()
    if path.len() == 0:
      discard showError("Please enter a path for the alias.")
    elif not dirExists(path) and path != "exit":
      path = ""
      discard showError("Please enter a path to the existing directory")
    if path.len() == 0:
      showOutput("Path: ", false)
  if path == "exit":
    return showError("Adding a new variable cancelled.")
  showOutput(message = "#####################", fgColor = fgYellow)
  showOutput(message = "(4/5) Recursiveness", fgColor = fgYellow)
  showOutput(message = "#####################", fgColor = fgYellow)
  showOutput("Select if variable is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press 'y' or 'n':")
  showOutput("Recursive(y/n): ", false)
  var inputChar: char = getch()
  while inputChar != 'n' and inputChar != 'N' and inputChar != 'y' and
      inputChar != 'Y':
    inputChar = getch()
  let recursive = if inputChar == 'n' or inputChar == 'N': 0 else: 1
  stdout.writeLine("")
  showOutput(message = "#####################", fgColor = fgYellow)
  showOutput(message = "(5/5) Value", fgColor = fgYellow)
  showOutput(message = "#####################", fgColor = fgYellow)
  showOutput("The value of the variable. For example: 'mykeytodatabase'. Value can't contain a new line character.:")
  showOutput("Value: ", false)
  var value = ""
  while value.len() == 0:
    value = readInput()
    if value.len() == 0:
      discard showError("Please enter value for the variable.")
      showOutput("Value: ", false)
  if value == "exit":
    return showError("Adding a new variable cancelled.")
  # Check if variable with the same parameters exists in the database
  if db.getValue(sql"SELECT id FROM aliases  WHERE name=? AND path=? AND recursive=? AND value=?",
      name, path, recursive, value).len() > 0:
    return showError("There is a variable with the same name, path and value in the database.")
  # Save the variable to the database
  if db.tryInsertID(sql"INSERT INTO variables (name, path, recursive, value, description) VALUES (?, ?, ?, ?, ?)",
      name, path, recursive, value, description) == -1:
    return showError("Can't add variable.")
  # Update history index and refresh the list of available variables
  historyIndex = updateHistory("variable add", db)
  setVariables(getCurrentDir(), db, getCurrentDir())
  return QuitSuccess

proc editVariable*(arguments: string; historyIndex: var int;
    db: DbConn): int {.gcsafe, sideEffect, raises: [EOFError, OSError, IOError,
    ValueError], tags: [ReadDbEffect, ReadIOEffect, WriteIOEffect,
    WriteDbEffect].} =
  ## Edit the selected variable
  if arguments.len() < 6:
    return showError("Enter the ID of the variable to edit.")
  let
    varId = arguments[5 .. ^1]
    row = db.getRow(sql"SELECT name, path, value, description FROM variables WHERE id=?",
    varId)
  if row[0] == "":
    return showError("The variable with the ID: " & varId &
      " doesn't exists.")
  showOutput("You can cancel editing the variable at any time by double press Escape key. You can also reuse a current value by pressing Enter.")
  showOutput("The name of the variable. Current value: '" & row[0] & "'")
  var name = readInput(aliasNameLength)
  if name == "exit":
    return showError("Editing the variable cancelled.")
  elif name == "":
    name = row[0]
  showOutput("The description of the variable. It will be show on the list of available variable. Current value: '" &
      row[3] & "'. Can't contains a new line character.: ")
  var description = readInput()
  if description == "exit":
    return showError("Editing the variable cancelled.")
  elif description == "":
    description = row[3]
  showOutput("The full path to the directory in which the variable will be available. If you want to have a global variable, set it to '/'. Current value: '" &
      row[1] & "'")
  var path = readInput()
  if path == "exit":
    return showError("Editing the variable cancelled.")
  elif path == "":
    path = row[1]
  showOutput("Select if variable is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press 'y' or 'n':")
  var inputChar: char = getch()
  while inputChar != 'n' and inputChar != 'N' and inputChar != 'y' and
      inputChar != 'Y':
    inputChar = getch()
  let recursive = if inputChar == 'n' or inputChar == 'N': 0 else: 1
  stdout.writeLine("")
  showOutput("The value of the variable. Current value: '" & row[2] &
      "'. Value can't contain a new line character.:")
  var value = readInput()
  if value == "exit":
    return showError("Editing the variable cancelled.")
  elif value == "":
    value = row[2]
  # Save the variable to the database
  if db.execAffectedRows(sql"UPDATE variables SET name=?, path=?, recursive=?, value=?, description=? where id=?",
      name, path, recursive, value, description, varId) != 1:
    return showError("Can't edit the variable.")
  # Update history index and refresh the list of available variables
  historyIndex = updateHistory("variable edit", db)
  setVariables(getCurrentDir(), db, getCurrentDir())
  return QuitSuccess
