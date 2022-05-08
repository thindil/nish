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

import std/[db_sqlite, os, re, strutils, tables, terminal]
import constants, history, input, output

type
  VariableName = string # Used to store variables names in the database.

using
  db: DbConn # Connection to the shell's database
  arguments: UserInput # The string with arguments entered by the user fot the command
  historyIndex: var HistoryRange # The index of the last command in the shell's history

proc buildQuery*(directory: DirectoryPath; fields: string): string {.gcsafe,
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
  var remainingDirectory: DirectoryPath = parentDir(path = directory)

  # Construct SQL querry, search for variables also defined in parent directories
  # if they are recursive
  while remainingDirectory != "":
    result.add(y = " OR (path='" & remainingDirectory & "' AND recursive=1)")
    remainingDirectory = parentDir(remainingDirectory)

  result.add(y = " ORDER BY id ASC")

proc setVariables*(newDirectory: DirectoryPath; db;
    oldDirectory: DirectoryPath = "") {.gcsafe, sideEffect, raises: [], tags: [
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
      for dbResult in db.fastRows(query = sql(query = buildQuery(
          directory = oldDirectory, fields = "name"))):
        try:
          delEnv(key = dbResult[0])
        except OSError as e:
          discard showError(message = "Can't delete environment variables. Reason:" & e.msg)
    except DbError as e:
      discard showError(message = "Can't read environment variables for the old directory. Reason:" & e.msg)
  # Set the new environment variables
  try:
    for dbResult in db.fastRows(query = sql(query = buildQuery(
        directory = newDirectory, fields = "name, value"))):
      try:
        var
          value: string = dbResult[1]
          variableIndex: ExtendedNatural = value.find(sub = '$')
        # Convert all environment variables inside the variable to their values
        while variableIndex > -1:
          var variableEnd: ExtendedNatural = value.find(
              pattern = re"[^a-zA-Z0-9]", start = variableIndex + 1)
          if variableEnd == -1:
            variableEnd = value.len()
          let variableName: string = value[variableIndex + 1..variableEnd - 1]
          value[variableIndex..variableEnd - 1] = getEnv(variableName)
          variableIndex = value.find(sub = '$', start = variableEnd)
        putEnv(key = dbResult[0], val = value)
      except OSError, RegexError:
        discard showError(message = "Can't set environment variables. Reason:" &
            getCurrentExceptionMsg())
  except DbError as e:
    discard showError(message = "Can't read environment variables for the new directory. Reason:" & e.msg)

proc initVariables*(helpContent: var HelpTable; db) {.gcsafe, sideEffect,
    raises: [], tags: [ReadDbEffect, WriteEnvEffect, WriteIOEffect,
    ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Initialize enviroment variables. Set help related to the variables and
  ## load the local environment variables
  ##
  ## PARAMETERS
  ##
  ## * helpContent - the HelpTable with help content of the shell
  ## * db          - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## The list of available environment variables in the current directory and
  ## the updated helpContent with the help for the commands related to the
  ## variables.
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

proc setCommand*(arguments; db): ResultCode {.gcsafe, sideEffect, raises: [],
    tags: [ReadIOEffect, ReadDbEffect, WriteIOEffect, WriteDbEffect,
        ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Build-in command to set the selected environment variable
  ##
  ## PARAMETERS
  ##
  ## * arguments - the user entered text with arguments for set variable
  ## * db        - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the environment variable was successfully set, otherwise
  ## QuitFailure
  if arguments.len() > 0:
    let varValues: seq[string] = arguments.split(sep = '=')
    if varValues.len() > 1:
      try:
        putEnv(key = varValues[0], val = varValues[1])
        showOutput(message = "Environment variable '" & varValues[0] &
            "' set to '" & varValues[1] & "'", fgColor = fgGreen)
        result = QuitSuccess
      except OSError as e:
        result = showError(message = "Can't set the environment variable '" &
            varValues[0] & "'. Reason:" & e.msg)
    else:
      result = showError(message = "You have to enter the name of the variable and its value.")
  else:
    result = showError(message = "You have to enter the name of the variable and its value.")
  discard updateHistory(commandToAdd = "set " & arguments, db = db,
      returnCode = result)

proc unsetCommand*(arguments; db): ResultCode {.gcsafe, sideEffect, raises: [],
    tags: [ReadIOEffect, ReadDbEffect, WriteIOEffect, WriteDbEffect,
        ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Build-in command to unset the selected environment variable
  ##
  ## PARAMETERS
  ##
  ## * arguments - the user entered text with arguments for unset variable
  ## * db        - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the environment variable was successfully unset, otherwise
  ## QuitFailure
  if arguments.len() > 0:
    try:
      delEnv(key = arguments)
      showOutput(message = "Environment variable '" & arguments & "' removed",
          fgColor = fgGreen)
      result = QuitSuccess
    except OSError as e:
      result = showError(message = "Can't unset the environment variable '" &
          arguments & "'. Reason:" & e.msg)
  else:
    result = showError(message = "You have to enter the name of the variable to unset.")
  discard updateHistory(commandToAdd = "unset " & arguments, db = db,
      returnCode = result)

proc listVariables*(arguments; historyIndex; db) {.gcsafe, sideEffect, raises: [
    ], tags: [ReadIOEffect, WriteIOEffect, ReadDbEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## List available variables, if entered command was "variables list all" list all
  ## declared variables then
  ##
  ## PARAMETERS
  ##
  ## * arguments    - the user entered text with arguments for list variables
  ## * historyIndex - the index of the last command in the shell's history
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## Updated value for the historyIndex argument
  let
    nameLength: ColumnAmount = try:
        db.getValue(query = sql(query = "SELECT name FROM variables ORDER BY LENGTH(name) DESC LIMIT 1")).len()
    except DbError:
      discard showError(message = "Can't get the maximum length of the variables names from database.")
      return
    valueLength: ColumnAmount = try:
        db.getValue(query = sql(query = "SELECT value FROM variables ORDER BY LENGTH(value) DESC LIMIT 1")).len()
    except DbError:
      discard showError(message = "Can't get the maximum length of the variables values from database.")
      return
    spacesAmount: ColumnAmount = try:
        (terminalWidth() / 12).int
      except ValueError:
        6
  if arguments == "list":
    showFormHeader(message = "Declared environent variables are:")
    try:
      showOutput(message = indent(s = "ID   $1 $2 Description" % [alignLeft(
          s = "Name", count = nameLength), alignLeft(s = "Value",
              count = valueLength)], count = spacesAmount), fgColor = fgMagenta)
    except ValueError as e:
      discard showError(message = "Can't draw header for variables. Reason: " & e.msg)
    try:
      for row in db.fastRows(query = sql(query = buildQuery(
          directory = getCurrentDir(), fields = "id, name, value, description"))):
        showOutput(message = indent(s = alignLeft(s = row[0], count = 4) & " " &
            alignLeft(s = row[1], count = nameLength) & " " & alignLeft(s = row[
                2], count = valueLength) & " " & row[3], count = spacesAmount))
    except DbError, OSError:
      discard showError(message = "Can't get the current directory name. Reason: " &
          getCurrentExceptionMsg())
      historyIndex = updateHistory(commandToAdd = "variable " & arguments,
          db = db, returnCode = QuitFailure)
      return
  elif arguments == "list all":
    showFormHeader(message = "All declared environent variables are:")
    try:
      showOutput(message = indent(s = "ID   $1 $2 Description" % [alignLeft(
          s = "Name", count = nameLength), alignLeft(s = "Value",
              count = valueLength)], count = spacesAmount), fgColor = fgMagenta)
    except ValueError as e:
      discard showError(message = "Can't draw header for variables. Reason: " & e.msg)
    try:
      for row in db.fastRows(query = sql(
          query = "SELECT id, name, value, description FROM variables")):
        showOutput(message = indent(s = alignLeft(s = row[0], count = 4) & " " &
            alignLeft(s = row[1], count = nameLength) & " " & alignLeft(s = row[
                2], count = valueLength) & " " & row[3], count = spacesAmount))
    except DbError as e:
      discard showError(message = "Can't read data about variables from database. Reason: " & e.msg)
      historyIndex = updateHistory(commandToAdd = "variable " & arguments,
          db = db, returnCode = QuitFailure)
      return
  historyIndex = updateHistory(commandToAdd = "variable " & arguments, db = db)

proc helpVariables*(db): HistoryRange {.gcsafe, sideEffect, raises: [], tags: [
    ReadDbEffect, WriteDbEffect, ReadIOEffect, WriteIOEffect, ReadEnvEffect,
    TimeEffect].} =
  ## FUNCTION
  ##
  ## Show short help about available subcommands related to the environment variables
  ##
  ## PARAMETERS
  ##
  ## * db - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## The new length of the shell's commands' history.
  showOutput(message = """Available subcommands are: list, delete, add, edit

        To see more information about the subcommand, type help variable [command],
        for example: help variable list.
""")
  return updateHistory(commandToAdd = "variable", db = db)

proc deleteVariable*(arguments; historyIndex; db): ResultCode {.gcsafe,
    sideEffect, raises: [], tags: [WriteIOEffect, ReadIOEffect, ReadDbEffect,
        WriteDbEffect, ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Delete the selected variable from the shell's database
  ##
  ## PARAMETERS
  ##
  ## * arguments    - the user entered text with arguments for delete the variable
  ## * historyIndex - the index of the last command in the shell's history
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the environment variable was successfully deleted, otherwise
  ## QuitFailure. Also, updated parameter historyIndex with new length of the
  ## shell's history
  if arguments.len() < 8:
    historyIndex = updateHistory(commandToAdd = "variable delete", db = db,
        returnCode = QuitFailure)
    return showError(message = "Enter the Id of the variable to delete.")
  let varId: DatabaseId = try:
      parseInt(arguments[7 .. ^1])
    except ValueError:
      return showError(message = "The Id of the variable must be a positive number.")
  try:
    if db.execAffectedRows(query = sql(query = (
        "DELETE FROM variables WHERE id=?")), varId) == 0:
      historyIndex = updateHistory(commandToAdd = "variable delete", db = db,
          returnCode = QuitFailure)
      return showError(message = "The variable with the Id: " & $varId &
        " doesn't exist.")
  except DbError as e:
    return showError(message = "Can't delete variable from database. Reason: " & e.msg)
  historyIndex = updateHistory(commandToAdd = "variable delete", db = db)
  try:
    setVariables(newDirectory = getCurrentDir(), db = db,
        oldDirectory = getCurrentDir())
  except OSError as e:
    return showError(message = "Can't set environment variables in the current directory. Reason: " & e.msg)
  showOutput(message = "Deleted the variable with Id: " & $varId,
      fgColor = fgGreen)
  return QuitSuccess

proc addVariable*(historyIndex; db): ResultCode {.gcsafe, sideEffect, raises: [
    ], tags: [ReadDbEffect, ReadIOEffect, WriteIOEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Add a new variable to the shell. Ask the user a few questions and fill the
  ## variable values with answers
  ##
  ## PARAMETERS
  ##
  ## * historyIndex - the index of the last command in the shell's history
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the environment variable was successfully added, otherwise
  ## QuitFailure. Also, updated parameter historyIndex with new length of the
  ## shell's history
  showOutput(message = "You can cancel adding a new variable at any time by double press Escape key.")
  showFormHeader(message = "(1/5) Name")
  showOutput(message = "The name of the variable. For example: 'MY_KEY'. Can't be empty and can contains only letters, numbers and underscores:")
  var name: VariableName = ""
  showOutput(message = "Name: ", newLine = false)
  while name.len() == 0:
    name = readInput(maxLength = aliasNameLength)
    if name.len() == 0:
      discard showError(message = "Please enter a name for the variable.")
    elif not name.validIdentifier:
      name = ""
      discard showError(message = "Please enter a valid name for the variable.")
    if name.len() == 0:
      showOutput(message = "Name: ", newLine = false)
  if name == "exit":
    return showError(message = "Adding a new variable cancelled.")
  showFormHeader(message = "(2/5) Description")
  showOutput(message = "The description of the variable. It will be show on the list of available variables. For example: 'My key to database.'. Can't contains a new line character.: ")
  showOutput(message = "Description: ", newLine = false)
  let description: UserInput = readInput()
  if description == "exit":
    return showError(message = "Adding a new variable cancelled.")
  showFormHeader(message = "(3/5) Working directory")
  showOutput(message = "The full path to the directory in which the variable will be available. If you want to have a global variable, set it to '/'. Can't be empty and must be a path to the existing directory.: ")
  showOutput(message = "Path: ", newLine = false)
  var path: DirectoryPath = ""
  while path.len() == 0:
    path = readInput()
    if path.len() == 0:
      discard showError(message = "Please enter a path for the alias.")
    elif not dirExists(dir = path) and path != "exit":
      path = ""
      discard showError(message = "Please enter a path to the existing directory")
    if path.len() == 0:
      showOutput(message = "Path: ", newLine = false)
  if path == "exit":
    return showError(message = "Adding a new variable cancelled.")
  showFormHeader(message = "(4/5) Recursiveness")
  showOutput(message = "Select if variable is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press 'y' or 'n':")
  showOutput(message = "Recursive(y/n): ", newLine = false)
  var inputChar: char = try:
      getch()
    except IOError:
      'y'
  while inputChar notin {'n', 'N', 'y', 'Y'}:
    inputChar = try:
      getch()
    except IOError:
      'y'
  let recursive: BooleanInt = if inputChar == 'n' or inputChar == 'N': 0 else: 1
  try:
    stdout.writeLine(x = "")
  except IOError:
    discard
  showFormHeader(message = "(5/5) Value")
  showOutput(message = "The value of the variable. For example: 'mykeytodatabase'. Value can't contain a new line character. Can't be empty.:")
  showOutput(message = "Value: ", newLine = false)
  var value: UserInput = ""
  while value.len() == 0:
    value = readInput()
    if value.len() == 0:
      discard showError(message = "Please enter value for the variable.")
      showOutput(message = "Value: ", newLine = false)
  if value == "exit":
    return showError(message = "Adding a new variable cancelled.")
  # Check if variable with the same parameters exists in the database
  try:
    if db.getValue(query = sql(query = "SELECT id FROM variables WHERE name=? AND path=? AND recursive=? AND value=?"),
        name, path, recursive, value).len() > 0:
      return showError(message = "There is a variable with the same name, path and value in the database.")
  except DbError as e:
    return showError(message = "Can't check if the same variable exists in the database. Reason: " & e.msg)
  # Save the variable to the database
  try:
    if db.tryInsertID(query = sql(query = "INSERT INTO variables (name, path, recursive, value, description) VALUES (?, ?, ?, ?, ?)"),
        name, path, recursive, value, description) == -1:
      return showError(message = "Can't add variable.")
  except DbError as e:
    return showError(message = "Can't add the variable to database. Reason: " & e.msg)
  # Update history index and refresh the list of available variables
  historyIndex = updateHistory(commandToAdd = "variable add", db = db)
  try:
    setVariables(newDirectory = getCurrentDir(), db = db,
        oldDirectory = getCurrentDir())
  except OSError as e:
    return showError(message = "Can't set variables for the current directory. Reason: " & e.msg)
  showOutput(message = "The new variable '" & name & "' added.",
      fgColor = fgGreen)
  return QuitSuccess

proc editVariable*(arguments; historyIndex; db): ResultCode {.gcsafe,
    sideEffect, raises: [], tags: [ReadDbEffect, ReadIOEffect, WriteIOEffect,
        WriteDbEffect, ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Edit the selected variable.  Ask the user a few questions and fill the
  ## variable values with answers
  ##
  ## PARAMETERS
  ##
  ## * arguments    - the user entered text with arguments for editing the variable
  ## * historyIndex - the index of the last command in the shell's history
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the environment variable was successfully updated, otherwise
  ## QuitFailure. Also, updated parameter historyIndex with new length of the
  ## shell's history
  if arguments.len() < 6:
    return showError(message = "Enter the ID of the variable to edit.")
  let varId: DatabaseId = try:
      parseInt(arguments[7 .. ^1])
    except ValueError:
      return showError(message = "The Id of the variable must be a positive number.")
  let
    row: Row = try:
        db.getRow(query = sql(query = "SELECT name, path, value, description FROM variables WHERE id=?"), varId)
      except DbError:
        return showError(message = "The variable with the ID: " & $varId & " doesn't exists.")
  showOutput(message = "You can cancel editing the variable at any time by double press Escape key. You can also reuse a current value by pressing Enter.")
  showFormHeader(message = "(1/5) Name")
  showOutput(message = "The name of the variable. Current value: '" & row[0] & "'. Can contains only letters, numbers and underscores.:")
  var name: VariableName = "exit"
  showOutput(message = "Name: ", newLine = false)
  while name.len() > 0:
    name = readInput(maxLength = aliasNameLength)
    if name.len() > 0 and not name.validIdentifier:
      discard showError(message = "Please enter a valid name for the variable.")
      showOutput(message = "Name: ", newLine = false)
    else:
      break
  if name == "exit":
    return showError(message = "Editing the variable cancelled.")
  elif name == "":
    name = row[0]
  showFormHeader(message = "(2/5) Description")
  showOutput(message = "The description of the variable. It will be show on the list of available variable. Current value: '" &
      row[3] & "'. Can't contains a new line character.: ")
  var description: UserInput = readInput()
  if description == "exit":
    return showError(message = "Editing the variable cancelled.")
  elif description == "":
    description = row[3]
  showFormHeader(message = "(3/5) Working directory")
  showOutput(message = "The full path to the directory in which the variable will be available. If you want to have a global variable, set it to '/'. Current value: '" &
      row[1] & "'. Must be a path to the existing directory.:")
  showOutput(message = "Path: ", newLine = false)
  var path: DirectoryPath = "exit"
  while path.len() > 0:
    path = readInput()
    if path.len() > 0 and not dirExists(dir = path) and path != "exit":
      discard showError(message = "Please enter a path to the existing directory")
      showOutput(message = "Path: ", newLine = false)
    else:
      break
  if path == "exit":
    return showError(message = "Editing the variable cancelled.")
  elif path == "":
    path = row[1]
  showFormHeader(message = "(4/5) Recursiveness")
  showOutput(message = "Select if variable is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press 'y' or 'n':")
  var inputChar: char = try:
      getch()
    except IOError:
      'y'
  while inputChar notin {'n', 'N', 'y', 'Y'}:
    inputChar = try:
      getch()
    except IOError:
      'y'
  let recursive: BooleanInt = if inputChar == 'n' or inputChar == 'N': 0 else: 1
  try:
    stdout.writeLine(x = "")
  except IOError:
    discard
  showFormHeader(message = "(5/5) Value")
  showOutput(message = "The value of the variable. Current value: '" & row[2] &
      "'. Value can't contain a new line character.:")
  var value: UserInput = readInput()
  if value == "exit":
    return showError(message = "Editing the variable cancelled.")
  elif value == "":
    value = row[2]
  # Save the variable to the database
  try:
    if db.execAffectedRows(query = sql(query = "UPDATE variables SET name=?, path=?, recursive=?, value=?, description=? where id=?"),
        name, path, recursive, value, description, varId) != 1:
      return showError(message = "Can't edit the variable.")
  except DbError as e:
    return showError(message = "Can't save the edits of the variable to database. Reason: " & e.msg)
  # Update history index and refresh the list of available variables
  historyIndex = updateHistory(commandToAdd = "variable edit", db = db)
  try:
    setVariables(newDirectory = getCurrentDir(), db = db,
        oldDirectory = getCurrentDir())
  except OSError as e:
    return showError(message = "Can't set variables for the current directory. Reason: " & e.msg)
  showOutput(message = "The variable  with Id: '" & $varId & "' edited.",
      fgColor = fgGreen)
  return QuitSuccess
