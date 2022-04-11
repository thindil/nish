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

using
  db: DbConn # Connection to the shell's database
  arguments: UserArguments # The string with arguments entered by the user fot the command
  historyIndex: var HistoryRange # The index of the last command in the shell's history

proc buildQuery(directory: DirectoryPath; fields: string): string {.gcsafe,
    sideEffect, raises: [], tags: [ReadDbEffect].} =
  ## FUNCTION
  ##
  ## Build database query for get environment variables for the selected
  ## directory and its parents
  ##
  ## PARAMETERS
  ##
  ## * directory - the directory path for which the database's query will be build
  ## * fields    - the database fields to retrieve by the database's query
  ##
  ## RETURNS
  ##
  ## The string with database's query for the selected directory and fields
  result = "SELECT " & fields & " FROM variables WHERE path='" & directory & "'"
  var remainingDirectory: DirectoryPath = parentDir(directory)

# Construct SQL querry, search for variables also defined in parent directories
  # if they are recursive
  while remainingDirectory != "":
    result.add(" OR (path='" & remainingDirectory & "' AND recursive=1)")
    remainingDirectory = parentDir(remainingDirectory)

  result.add(" ORDER BY id ASC")

proc setVariables*(newDirectory: string; db;
    oldDirectory: string = "") {.gcsafe, sideEffect, raises: [], tags: [
    ReadDbEffect, WriteEnvEffect, WriteIOEffect, ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Set the environment variables in the selected directory and remove the
  ## old ones
  ##
  ## PARAMETERS
  ##
  ## * newDirectory - the new directory in which environment variables will be
  ##                  set
  ## * db           - the connection to the shell's database
  ## * oldDirectory - the old directory in which environment variables will be
  ##                  removed. Can be empty. Default value is empty

  # Remove the old environment variables if needed
  if oldDirectory.len() > 0:
    try:
      for dbResult in db.fastRows(sql(buildQuery(oldDirectory, "name"))):
        try:
          delEnv(dbResult[0])
        except OSError as e:
          discard showError("Can't delete environment variables. Reason:" & e.msg)
    except DbError as e:
      discard showError("Can't read environment variables for the old directory. Reason:" & e.msg)
  # Set the new environment variables
  try:
    for dbResult in db.fastRows(sql(buildQuery(newDirectory, "name, value"))):
      try:
        putEnv(dbResult[0], dbResult[1])
      except OSError as e:
        discard showError("Can't set environment variables. Reason:" & e.msg)
  except DbError as e:
    discard showError("Can't read environment variables for the new directory. Reason:" & e.msg)

proc initVariables*(helpContent: var HelpTable; db) {.gcsafe, sideEffect,
    raises: [], tags: [ReadDbEffect, WriteEnvEffect, WriteIOEffect,
    ReadEnvEffect, TimeEffect].} =
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
  try:
    setVariables(getCurrentDir(), db)
  except OSError as e:
    discard showError("Can't set environment variables for the current directory. Reason:" & e.msg)

proc setCommand*(arguments; db): int {.gcsafe, sideEffect, raises: [], tags: [
    ReadIOEffect, ReadDbEffect, WriteIOEffect, WriteDbEffect, ReadEnvEffect,
    TimeEffect].} =
  ## Build-in command to set the selected environment variable
  if arguments.len() > 0:
    let varValues: seq[string] = arguments.split("=")
    if varValues.len() > 1:
      try:
        putEnv(varValues[0], varValues[1])
        showOutput(message = "Environment variable '" & varValues[0] &
            "' set to '" & varValues[1] & "'", fgColor = fgGreen)
        result = QuitSuccess
      except OSError as e:
        result = showError("Can't set the environment variable '" & varValues[
            0] & "'. Reason:" & e.msg)
    else:
      result = showError("You have to enter the name of the variable and its value.")
  else:
    result = showError("You have to enter the name of the variable and its value.")
  discard updateHistory("set " & arguments, db, result)

proc unsetCommand*(arguments; db): int {.gcsafe, sideEffect, raises: [], tags: [
    ReadIOEffect, ReadDbEffect, WriteIOEffect, WriteDbEffect, ReadEnvEffect,
        TimeEffect].} =
  ## Build-in command to unset the selected environment variable
  if arguments.len() > 0:
    try:
      delEnv(arguments)
      showOutput(message = "Environment variable '" & arguments & "' removed",
          fgColor = fgGreen)
      result = QuitSuccess
    except OSError as e:
      result = showError("Can't unset the environment variable '" & arguments &
          "'. Reason:" & e.msg)
  else:
    result = showError("You have to enter the name of the variable to unset.")
  discard updateHistory("unset " & arguments, db, result)

proc listVariables*(arguments; historyIndex; db) {.gcsafe, sideEffect, raises: [
    ], tags: [ReadIOEffect, WriteIOEffect, ReadDbEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect].} =
  ## List available variables, if entered command was "variables list all" list all
  ## declared variables then
  let
    nameLength: Natural = (try: db.getValue(
        sql"SELECT name FROM variables ORDER BY LENGTH(name) DESC LIMIT 1").len() except DbError: 0)
    valueLength: Natural = (try: db.getValue(
        sql"SELECT value FROM variables ORDER BY LENGTH(value) DESC LIMIT 1").len() except DbError: 0)
    spacesAmount: Natural = (try: (terminalWidth() /
        12).int except ValueError: 6)
  if nameLength == 0:
    discard showError("Can't get the maximum length of the variables names from database.")
    return
  if valueLength == 0:
    discard showError("Can't get the maximum length of the variables values from database.")
    return
  if arguments == "list":
    showFormHeader("Declared environent variables are:")
    try:
      showOutput(message = indent("ID   $1 $2 Description" % [alignLeft("Name",
          nameLength), alignLeft("Value", valueLength)], spacesAmount),
              fgColor = fgMagenta)
    except ValueError as e:
      discard showError("Can't draw header for variables. Reason: " & e.msg)
    try:
      for row in db.fastRows(sql(buildQuery(getCurrentDir(),
          "id, name, value, description"))):
        showOutput(indent(alignLeft(row[0], 4) & " " & alignLeft(row[1],
            nameLength) & " " & alignLeft(row[2], valueLength) & " " & row[3], spacesAmount))
    except DbError, OSError:
      discard showError("Can't get the current directory name. Reason: " &
          getCurrentExceptionMsg())
      historyIndex = updateHistory("variable " & arguments, db, QuitFailure)
      return
  elif arguments == "list all":
    showFormHeader("All declared environent variables are:")
    try:
      showOutput(message = indent("ID   $1 $2 Description" % [alignLeft("Name",
          nameLength), alignLeft("Value", valueLength)], spacesAmount),
              fgColor = fgMagenta)
    except ValueError as e:
      discard showError("Can't draw header for variables. Reason: " & e.msg)
    try:
      for row in db.fastRows(sql"SELECT id, name, value, description FROM variables"):
        showOutput(indent(alignLeft(row[0], 4) & " " & alignLeft(row[1],
            nameLength) & " " & alignLeft(row[2], valueLength) & " " & row[3], spacesAmount))
    except DbError as e:
      discard showError("Can't read data about variables from database. Reason: " & e.msg)
      historyIndex = updateHistory("variable " & arguments, db, QuitFailure)
      return
  historyIndex = updateHistory("variable " & arguments, db)

proc helpVariables*(db): HistoryRange {.gcsafe, sideEffect, raises: [], tags: [
    ReadDbEffect, WriteDbEffect, ReadIOEffect, WriteIOEffect, ReadEnvEffect,
    TimeEffect].} =
  ## Show short help about available subcommands related to the environment variables
  showOutput("""Available subcommands are: list, delete, add, edit

        To see more information about the subcommand, type help variable [command],
        for example: help variable list.
""")
  return updateHistory("variable", db)

proc deleteVariable*(arguments; historyIndex; db): int {.gcsafe, sideEffect,
    raises: [], tags: [WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect].} =
  ## Delete the selected variable from the shell's database
  if arguments.len() < 8:
    historyIndex = updateHistory("variable delete", db, QuitFailure)
    return showError("Enter the Id of the variable to delete.")
  let varName: string = arguments[7 .. ^1]
  try:
    if db.execAffectedRows(sql"DELETE FROM variables WHERE id=?",
        varName) == 0:
      historyIndex = updateHistory("variable delete", db, QuitFailure)
      return showError("The variable with the Id: " & varName &
        " doesn't exist.")
  except DbError as e:
    return showError("Can't delete variable from database. Reason: " & e.msg)
  historyIndex = updateHistory("variable delete", db)
  try:
    setVariables(getCurrentDir(), db, getCurrentDir())
  except OSError as e:
    return showError("Can't set environment variables in the current directory. Reason: " & e.msg)
  showOutput(message = "Deleted the variable with Id: " & varName,
      fgColor = fgGreen)
  return QuitSuccess

proc addVariable*(historyIndex; db): int {.gcsafe, sideEffect, raises: [],
    tags: [ReadDbEffect, ReadIOEffect, WriteIOEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect].} =
  ## Add a new variable to the shell. Ask the user a few questions and fill the
  ## variable values with answers
  showOutput("You can cancel adding a new variable at any time by double press Escape key.")
  showFormHeader("(1/5) Name")
  showOutput("The name of the variable. For example: 'MY_KEY'. Can't be empty and can contains only letters, numbers and underscores:")
  var name: string = ""
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
  showFormHeader("(2/5) Description")
  showOutput("The description of the variable. It will be show on the list of available variables. For example: 'My key to database.'. Can't contains a new line character.: ")
  showOutput("Description: ", false)
  let description: string = readInput()
  if description == "exit":
    return showError("Adding a new variable cancelled.")
  showFormHeader("(3/5) Working directory")
  showOutput("The full path to the directory in which the variable will be available. If you want to have a global variable, set it to '/'. Can't be empty and must be a path to the existing directory.: ")
  showOutput("Path: ", false)
  var path: string = ""
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
  showFormHeader("(4/5) Recursiveness")
  showOutput("Select if variable is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press 'y' or 'n':")
  showOutput("Recursive(y/n): ", false)
  var inputChar: char = (try: getch() except IOError: 'y')
  while inputChar != 'n' and inputChar != 'N' and inputChar != 'y' and
      inputChar != 'Y':
    inputChar = (try: getch() except IOError: 'y')
  let recursive: int = if inputChar == 'n' or inputChar == 'N': 0 else: 1
  try:
    stdout.writeLine("")
  except IOError:
    discard
  showFormHeader("(5/5) Value")
  showOutput("The value of the variable. For example: 'mykeytodatabase'. Value can't contain a new line character. Can't be empty.:")
  showOutput("Value: ", false)
  var value: string = ""
  while value.len() == 0:
    value = readInput()
    if value.len() == 0:
      discard showError("Please enter value for the variable.")
      showOutput("Value: ", false)
  if value == "exit":
    return showError("Adding a new variable cancelled.")
  # Check if variable with the same parameters exists in the database
  try:
    if db.getValue(sql"SELECT id FROM variables WHERE name=? AND path=? AND recursive=? AND value=?",
        name, path, recursive, value).len() > 0:
      return showError("There is a variable with the same name, path and value in the database.")
  except DbError as e:
    return showError("Can't check if the same variable exists in the database. Reason: " & e.msg)
  # Save the variable to the database
  try:
    if db.tryInsertID(sql"INSERT INTO variables (name, path, recursive, value, description) VALUES (?, ?, ?, ?, ?)",
        name, path, recursive, value, description) == -1:
      return showError("Can't add variable.")
  except DbError as e:
    return showError("Can't add the variable to database. Reason: " & e.msg)
  # Update history index and refresh the list of available variables
  historyIndex = updateHistory("variable add", db)
  try:
    setVariables(getCurrentDir(), db, getCurrentDir())
  except OSError as e:
    return showError("Can't set variables for the current directory. Reason: " & e.msg)
  showOutput(message = "The new variable '" & name & "' added.",
      fgColor = fgGreen)
  return QuitSuccess

proc editVariable*(arguments; historyIndex; db): int {.gcsafe, sideEffect,
    raises: [], tags: [ReadDbEffect, ReadIOEffect, WriteIOEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect].} =
  ## Edit the selected variable
  if arguments.len() < 6:
    return showError("Enter the ID of the variable to edit.")
  let
    varId: string = arguments[5 .. ^1]
    row: Row = (try: db.getRow(sql"SELECT name, path, value, description FROM variables WHERE id=?",
    varId) except DbError: @["", "", "", ""])
  if row[0] == "":
    return showError("The variable with the ID: " & varId &
      " doesn't exists.")
  showOutput("You can cancel editing the variable at any time by double press Escape key. You can also reuse a current value by pressing Enter.")
  showFormHeader("(1/5) Name")
  showOutput("The name of the variable. Current value: '" & row[0] & "'. Can contains only letters, numbers and underscores.:")
  var name: string = "exit"
  showOutput("Name: ", false)
  while name.len() > 0:
    name = readInput(aliasNameLength)
    if name.len() > 0 and not name.validIdentifier:
      discard showError("Please enter a valid name for the variable.")
      showOutput("Name: ", false)
    else:
      break
  if name == "exit":
    return showError("Editing the variable cancelled.")
  elif name == "":
    name = row[0]
  showFormHeader("(2/5) Description")
  showOutput("The description of the variable. It will be show on the list of available variable. Current value: '" &
      row[3] & "'. Can't contains a new line character.: ")
  var description: string = readInput()
  if description == "exit":
    return showError("Editing the variable cancelled.")
  elif description == "":
    description = row[3]
  showFormHeader("(3/5) Working directory")
  showOutput("The full path to the directory in which the variable will be available. If you want to have a global variable, set it to '/'. Current value: '" &
      row[1] & "'. Must be a path to the existing directory.:")
  showOutput("Path: ", false)
  var path: string = "exit"
  while path.len() > 0:
    path = readInput()
    if path.len() > 0 and not dirExists(path) and path != "exit":
      discard showError("Please enter a path to the existing directory")
      showOutput("Path: ", false)
    else:
      break
  if path == "exit":
    return showError("Editing the variable cancelled.")
  elif path == "":
    path = row[1]
  showFormHeader("(4/5) Recursiveness")
  showOutput("Select if variable is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press 'y' or 'n':")
  var inputChar: char = (try: getch() except IOError: 'y')
  while inputChar != 'n' and inputChar != 'N' and inputChar != 'y' and
      inputChar != 'Y':
    inputChar = (try: getch() except IOError: 'y')
  let recursive: int = if inputChar == 'n' or inputChar == 'N': 0 else: 1
  try:
    stdout.writeLine("")
  except IOError:
    discard
  showFormHeader("(5/5) Value")
  showOutput("The value of the variable. Current value: '" & row[2] &
      "'. Value can't contain a new line character.:")
  var value: string = readInput()
  if value == "exit":
    return showError("Editing the variable cancelled.")
  elif value == "":
    value = row[2]
  # Save the variable to the database
  try:
    if db.execAffectedRows(sql"UPDATE variables SET name=?, path=?, recursive=?, value=?, description=? where id=?",
        name, path, recursive, value, description, varId) != 1:
      return showError("Can't edit the variable.")
  except DbError as e:
    return showError("Can't save the edits of the variable to database. Reason: " & e.msg)
  # Update history index and refresh the list of available variables
  historyIndex = updateHistory("variable edit", db)
  try:
    setVariables(getCurrentDir(), db, getCurrentDir())
  except OSError as e:
    return showError("Can't set variables for the current directory. Reason: " & e.msg)
  showOutput(message = "The variable  with Id: '" & varId & "' edited.",
      fgColor = fgGreen)
  return QuitSuccess
