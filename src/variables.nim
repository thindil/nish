# Copyright © 2022-2023 Bartek Jasicki
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

## This module contains code related to the environment variables set by the
## shell, like adding, editing or deleting variables or setting or unsetting
## the standard environment variables.

# Standard library imports
import std/[os, strutils, terminal]
# Database library import, depends on version of Nim
when (NimMajor, NimMinor, NimPatch) >= (1, 7, 3):
  import db_connector/db_sqlite
else:
  import std/db_sqlite
# External modules imports
import ansiparse, contracts, nancy, termstyle
import norm/[model, pragmas, sqlite]
# Internal imports
import commandslist, constants, databaseid, directorypath, help, input, lstring,
    output, resultcode

const
  variableNameLength*: Positive = maxNameLength
    ## The maximum length of the shell's environment variable name

  variablesCommands*: array[4, string] = ["list", "delete", "add", "edit"]
    ## The list of available subcommands for command variable

type
  VariableName = LimitedString # Used to store variables names in the database.
  Variable* {.tableName: "variables".} = ref object of Model
    ## Data structure for the shell's environment variable
    ##
    ## * name        - the name of the variable
    ## * path        - the path in which the variable exists
    ## * recursive   - if true, the variable is available also in subdirectories
    ## * value       - the value of the variable
    ## * description - the description of the variable
    name*: string
    path*: string
    recursive*: bool
    value*: string
    description*: string

using
  db: db_sqlite.DbConn # Connection to the shell's database
  arguments: UserInput # The string with arguments entered by the user for the command

proc buildQuery*(directory: DirectoryPath; fields: string = "";
    where: string = ""): string {.gcsafe, sideEffect, raises: [], tags: [
    ReadDbEffect], contractual.} =
  ## Build database query for get environment variables for the selected
  ## directory and its parents
  ##
  ## * directory - the directory path for which the database's query will be build
  ## * fields    - the database fields to retrieve by the database's query
  ## * where     - the optional arguments for WHERE statement. Can be empty.
  ##               Default value is empty.
  ##
  ## Returns the string with database's query for the selected directory and fields
  require:
    directory.len > 0
  body:
    result = (if fields.len > 0: "SELECT " & fields &
        " FROM variables WHERE " else: "") & "path='" & directory & "'"
    var remainingDirectory: DirectoryPath = parentDir(
        path = $directory).DirectoryPath

    # Construct SQL querry, search for variables also defined in parent directories
    # if they are recursive
    while remainingDirectory != "":
      result.add(y = " OR (path='" & remainingDirectory & "' AND recursive=1)")
      remainingDirectory = parentDir(path = $remainingDirectory).DirectoryPath

    # If optional arguments entered, add them to the query
    if where.len > 0:
      result.add(y = " " & where)

    result.add(y = " ORDER BY id ASC")

proc newVariable*(name: string = ""; path: string = ""; recursive: bool = false;
    value: string = ""; description: string = ""): Variable {.raises: [],
    tags: [], contractual.} =
  ## Create a new data structure for the shell's environment variable.
  ##
  ## * name        - the name of the variable. Must be unique
  ## * path        - the path in which the variabel will be available
  ## * recursive   - if true, the variable should work in children directories
  ##                 of the path too. Default value is false
  ## * value       - the value of the variable
  ## * description - the description of the variable
  ##
  ## Returns the new data structure for the selected shell's environment
  ## variable.
  body:
    Variable(name: name, path: path, recursive: recursive, value: value,
        description: description)

proc setVariables*(newDirectory: DirectoryPath; db;
    oldDirectory: DirectoryPath = "".DirectoryPath) {.sideEffect,
    raises: [], tags: [ReadDbEffect, WriteEnvEffect, WriteIOEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Set the environment variables in the selected directory and remove the
  ## old ones
  ##
  ## * newDirectory - the new directory in which environment variables will be
  ##                  set
  ## * db           - the connection to the shell's database
  ## * oldDirectory - the old directory in which environment variables will be
  ##                  removed. Can be empty. Default value is empty
  require:
    newDirectory.len > 0
    db != nil
  body:
    var skipped: seq[int] = @[]

    # Remove the old environment variables if needed
    if oldDirectory.len > 0:
      try:
        var variables: seq[Variable] = @[newVariable()]
        db.select(objs = variables, cond = buildQuery(directory = oldDirectory))
        for variable in variables:
          if not db.exists(T = Variable, cond = buildQuery(
              directory = newDirectory, where = "AND name='" & variable.name &
              "' AND value='" & variable.value & "'")):
            delEnv(key = variable.name)
          else:
            skipped.add(y = variable.id)
      except:
        showError(message = "Can't delete environment variables from the old directory. Reason: ",
            e = getCurrentException())
    # Set the new environment variables
    try:
      var variables: seq[Variable] = @[newVariable()]
      db.select(objs = variables, cond = buildQuery(directory = newDirectory))
      for variable in variables:
        if variable.id in skipped:
          continue
        var
          value: string = variable.value
          variableIndex: ExtendedNatural = value.find(sub = '$')
        # Convert all environment variables inside the variable to their values
        while variableIndex in 0..(value.len - 1):
          var variableEnd: ExtendedNatural = variableIndex + 1
          # Variables names can start only with letters
          if not isAlphaAscii(c = value[variableEnd]):
            variableIndex = value.find(sub = '$', start = variableEnd)
            continue
          # Variables names can contain only letters and numbers
          while variableEnd < value.len and value[variableEnd].isAlphaNumeric:
            variableEnd.inc
          if variableEnd > value.len:
            variableEnd = value.len
          let variableName: string = value[variableIndex + 1..variableEnd - 1]
          value[variableIndex..variableEnd - 1] = getEnv(key = variableName)
          variableIndex = value.find(sub = '$', start = variableEnd)
        putEnv(key = variable.name, val = value)
    except:
      showError(message = "Can't set environment variables for the new directory. Reason: ",
          e = getCurrentException())

proc setCommand*(arguments): ResultCode {.gcsafe, sideEffect, raises: [],
    tags: [ReadIOEffect, ReadDbEffect, WriteIOEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Build-in command to set the selected environment variable
  ##
  ## * arguments - the user entered text with arguments for set variable
  ##
  ## Returns QuitSuccess if the environment variable was successfully set, otherwise
  ## QuitFailure
  body:
    if arguments.len == 0:
      return showError(message = "You have to enter the name of the variable and its value.")
    let varValues: seq[string] = split(s = $arguments, sep = '=')
    if varValues.len < 2:
      return showError(message = "You have to enter the name of the variable and its value.")
    try:
      putEnv(key = varValues[0], val = varValues[1])
      showOutput(message = "Environment variable '" & varValues[0] &
          "' set to '" & varValues[1] & "'", fgColor = fgGreen)
      return QuitSuccess.ResultCode
    except OSError:
      return showError(message = "Can't set the environment variable '" &
          varValues[0] & "'. Reason:", e = getCurrentException())

proc unsetCommand*(arguments): ResultCode {.gcsafe, sideEffect, raises: [],
    tags: [ReadIOEffect, ReadDbEffect, WriteIOEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Build-in command to unset the selected environment variable
  ##
  ## * arguments - the user entered text with arguments for unset variable
  ##
  ## Returns QuitSuccess if the environment variable was successfully unset, otherwise
  ## QuitFailure
  body:
    if arguments.len == 0:
      return showError(message = "You have to enter the name of the variable to unset.")
    try:
      delEnv(key = $arguments)
      showOutput(message = "Environment variable '" & arguments & "' removed",
          fgColor = fgGreen)
      return QuitSuccess.ResultCode
    except OSError:
      return showError(message = "Can't unset the environment variable '" &
          arguments & "'. Reason:", e = getCurrentException())

proc listVariables*(arguments; db): ResultCode {.sideEffect, raises: [], tags: [
    ReadIOEffect, WriteIOEffect, ReadDbEffect, WriteDbEffect, ReadEnvEffect,
    TimeEffect, RootEffect], contractual.} =
  ## List available variables, if entered command was "variables list all" list all
  ## declared variables then
  ##
  ## * arguments    - the user entered text with arguments for list variables
  ## * db           - the connection to the shell's database
  ##
  ## Returns QuitSucces if variables are properly listed, otherwise QuitFailure
  require:
    arguments.len > 0
    db != nil
  body:
    var
      table: TerminalTable = TerminalTable()
      variables: seq[Variable] = @[newVariable()]
    try:
      table.add(parts = [magenta(ss = "ID"), magenta(ss = "Name"), magenta(
          ss = "Value"), magenta(ss = "Description")])
    except UnknownEscapeError, InsufficientInputError, FinalByteError:
      return showError(message = "Can't show variables list. Reason: ",
          e = getCurrentException())
    # Show the list of all declared environment variables in the shell
    if arguments == "list all":
      try:
        db.selectAll(objs = variables)
        if variables.len == 0:
          showOutput(message = "There are no defined shell's environment variables.")
          return QuitSuccess.ResultCode
        for variable in variables:
          table.add(parts = [$variable.id, variable.name, variable.value,
              variable.description])
      except:
        return showError(message = "Can't read data about variables from database. Reason: ",
            e = getCurrentException())
      var width: int = 0
      for size in table.getColumnSizes(maxSize = int.high):
        width = width + size
      showFormHeader(message = "All declared environent variables are:",
          width = width.ColumnAmount, db = db)
    # Show the list of environment variables available in current directory
    elif arguments[0..3] == "list":
      try:
        db.select(objs = variables, cond = buildQuery(
            directory = getCurrentDirectory().DirectoryPath))
        if variables.len == 0:
          showOutput(message = "There are no defined shell's environment variables in this directory.")
          return QuitSuccess.ResultCode
        for variable in variables:
          table.add(parts = [$variable.id, variable.name, variable.value,
              variable.description])
      except:
        return showError(message = "Can't get the current directory name. Reason: ",
            e = getCurrentException())
      var width: int = 0
      for size in table.getColumnSizes(maxSize = int.high):
        width = width + size
      showFormHeader(message = "Declared environent variables are:",
          width = width.ColumnAmount, db = db)
    try:
      table.echoTable
    except IOError, Exception:
      return showError(message = "Can't show the list of declared shell's environment variables. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc deleteVariable*(arguments; db): ResultCode {.gcsafe, sideEffect, raises: [
    ], tags: [WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Delete the selected variable from the shell's database
  ##
  ## * arguments    - the user entered text with arguments for delete the variable
  ## * db           - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the environment variable was successfully deleted, otherwise
  ## QuitFailure.
  require:
    arguments.len > 0
    db != nil
  body:
    if arguments.len < 8:
      return showError(message = "Enter the Id of the variable to delete.")
    let varId: DatabaseId = try:
        ($arguments[7 .. ^1]).parseInt.DatabaseId
      except ValueError:
        return showError(message = "The Id of the variable must be a positive number.")
    try:
      if db.execAffectedRows(query = sql(query = (
          "DELETE FROM variables WHERE id=?")), args = varId) == 0:
        return showError(message = "The variable with the Id: " & $varId &
          " doesn't exist.")
    except DbError:
      return showError(message = "Can't delete variable from database. Reason: ",
          e = getCurrentException())
    try:
      setVariables(newDirectory = getCurrentDirectory().DirectoryPath, db = db,
          oldDirectory = getCurrentDirectory().DirectoryPath)
    except OSError:
      return showError(message = "Can't set environment variables in the current directory. Reason: ",
          e = getCurrentException())
    showOutput(message = "Deleted the variable with Id: " & $varId,
        fgColor = fgGreen)
    return QuitSuccess.ResultCode

proc addVariable*(db): ResultCode {.sideEffect, raises: [], tags: [ReadDbEffect,
    ReadIOEffect, WriteIOEffect, WriteDbEffect, ReadEnvEffect, TimeEffect,
    RootEffect], contractual.} =
  ## Add a new variable to the shell. Ask the user a few questions and fill the
  ## variable values with answers
  ##
  ## * db           - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the environment variable was successfully added, otherwise
  ## QuitFailure.
  require:
    db != nil
  body:
    showOutput(message = "You can cancel adding a new variable at any time by double press Escape key or enter word 'exit' as an answer.")
    # Set the name for the variable
    showFormHeader(message = "(1/5) Name", db = db)
    showOutput(message = "The name of the variable. For example: 'MY_KEY'. Can't be empty and can contains only letters, numbers and underscores:")
    var name: VariableName = emptyLimitedString(capacity = variableNameLength)
    showOutput(message = "Name: ", newLine = false)
    while name.len == 0:
      name = readInput(maxLength = variableNameLength)
      if name.len == 0:
        showError(message = "Please enter a name for the variable.")
      elif not validIdentifier(s = $name):
        try:
          name.text = ""
          showError(message = "Please enter a valid name for the variable.")
        except CapacityError:
          showError(message = "Can't set empty name for variable.")
      if name.len == 0:
        showOutput(message = "Name: ", newLine = false)
    if name == "exit":
      return showError(message = "Adding a new variable cancelled.")
    # Set the description for the variable
    showFormHeader(message = "(2/5) Description", db = db)
    showOutput(message = "The description of the variable. It will be show on the list of available variables. For example: 'My key to database.'. Can't contains a new line character.: ")
    showOutput(message = "Description: ", newLine = false)
    let description: UserInput = readInput()
    if description == "exit":
      return showError(message = "Adding a new variable cancelled.")
    # Set the working directory for the variable
    showFormHeader(message = "(3/5) Working directory", db = db)
    showOutput(message = "The full path to the directory in which the variable will be available. If you want to have a global variable, set it to '/'. Can't be empty and must be a path to the existing directory.: ")
    showOutput(message = "Path: ", newLine = false)
    var path: DirectoryPath = "".DirectoryPath
    while path.len == 0:
      path = ($readInput()).DirectoryPath
      if path.len == 0:
        showError(message = "Please enter a path for the alias.")
      elif not dirExists(dir = $path) and path != "exit":
        path = "".DirectoryPath
        showError(message = "Please enter a path to the existing directory")
      if path.len == 0:
        showOutput(message = "Path: ", newLine = false)
    if path == "exit":
      return showError(message = "Adding a new variable cancelled.")
    # Set the recursiveness for the variable
    showFormHeader(message = "(4/5) Recursiveness", db = db)
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
    # Set the value for the variable
    showFormHeader(message = "(5/5) Value", db = db)
    showOutput(message = "The value of the variable. For example: 'mykeytodatabase'. Value can't contain a new line character. Can't be empty.:")
    showOutput(message = "Value: ", newLine = false)
    var value: UserInput = emptyLimitedString(capacity = maxInputLength)
    while value.len == 0:
      value = readInput()
      if value.len == 0:
        showError(message = "Please enter value for the variable.")
        showOutput(message = "Value: ", newLine = false)
    if value == "exit":
      return showError(message = "Adding a new variable cancelled.")
    # Check if variable with the same parameters exists in the database
    try:
      if db.getValue(query = sql(query = "SELECT id FROM variables WHERE name=? AND path=? AND recursive=? AND value=?"),
          args = [$name, $path, $recursive, $value]).len > 0:
        return showError(message = "There is a variable with the same name, path and value in the database.")
    except DbError:
      return showError(message = "Can't check if the same variable exists in the database. Reason: ",
          e = getCurrentException())
    # Save the variable to the database
    try:
      if db.tryInsertID(query = sql(query = "INSERT INTO variables (name, path, recursive, value, description) VALUES (?, ?, ?, ?, ?)"),
          args = [$name, $path, $recursive, $value, $description]) == -1:
        return showError(message = "Can't add variable.")
    except DbError:
      return showError(message = "Can't add the variable to database. Reason: ",
          e = getCurrentException())
    try:
      setVariables(newDirectory = getCurrentDirectory().DirectoryPath, db = db,
          oldDirectory = getCurrentDirectory().DirectoryPath)
    except OSError:
      return showError(message = "Can't set variables for the current directory. Reason: ",
          e = getCurrentException())
    showOutput(message = "The new variable '" & name & "' added.",
        fgColor = fgGreen)
    return QuitSuccess.ResultCode

proc editVariable*(arguments; db): ResultCode {.sideEffect, raises: [], tags: [
    ReadDbEffect, ReadIOEffect, WriteIOEffect, WriteDbEffect, ReadEnvEffect,
    TimeEffect, RootEffect], contractual.} =
  ## Edit the selected variable.  Ask the user a few questions and fill the
  ## variable values with answers
  ##
  ## * arguments    - the user entered text with arguments for editing the variable
  ## * db           - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the environment variable was successfully updated, otherwise
  ## QuitFailure.
  require:
    arguments.len > 0
    db != nil
  body:
    if arguments.len < 6:
      return showError(message = "Enter the ID of the variable to edit.")
    let varId: DatabaseId = try:
        ($arguments[5 .. ^1]).parseInt.DatabaseId
      except ValueError:
        return showError(message = "The Id of the variable must be a positive number.")
    let
      row: db_sqlite.Row = try:
          db.getRow(query = sql(query = "SELECT name, path, value, description FROM variables WHERE id=?"), args = varId)
        except DbError:
          return showError(message = "The variable with the ID: " & $varId & " doesn't exists.")
    showOutput(message = "You can cancel editing the variable at any time by double press Escape key or enter word 'exit' as an answer. You can also reuse a current value by pressing Enter.")
    # Set the name for the variable
    showFormHeader(message = "(1/5) Name", db = db)
    showOutput(message = "The name of the variable. Current value: '",
        newLine = false)
    showOutput(message = row[0], newLine = false, fgColor = fgMagenta)
    showOutput(message = "'. Can contains only letters, numbers and underscores.:")
    var name: VariableName = try:
        initLimitedString(capacity = variableNameLength, text = "exit")
      except CapacityError:
        return showError(message = "Can't set name of the variable")
    showOutput(message = "Name: ", newLine = false)
    while name.len > 0:
      name = readInput(maxLength = variableNameLength)
      if name.len > 0 and not validIdentifier(s = $name):
        showError(message = "Please enter a valid name for the variable.")
        showOutput(message = "Name: ", newLine = false)
      else:
        break
    if name == "exit":
      return showError(message = "Editing the variable cancelled.")
    elif name == "":
      try:
        name.text = row[0]
      except CapacityError:
        return showError(message = "Editing the variable cancelled. Reason: can't set name for the variable.")
    # Set the description for the variable
    showFormHeader(message = "(2/5) Description", db = db)
    showOutput(message = "The description of the variable. It will be show on the list of available variable. Current value: '",
        newLine = false)
    showOutput(message = row[3], newLine = false, fgColor = fgMagenta)
    showOutput(message = "'. Can't contains a new line character.: ")
    var description: UserInput = readInput()
    if description == "exit":
      return showError(message = "Editing the variable cancelled.")
    elif description == "":
      try:
        description.text = row[3]
      except CapacityError:
        return showError(message = "Editing the variable cancelled. Reason: can't set description for the variable.")
    # Set the working directory for the variable
    showFormHeader(message = "(3/5) Working directory", db = db)
    showOutput(message = "The full path to the directory in which the variable will be available. If you want to have a global variable, set it to '/'. Current value: '",
        newLine = false)
    showOutput(message = row[1], newLine = false, fgColor = fgMagenta)
    showOutput(message = "'. Must be a path to the existing directory.:")
    showOutput(message = "Path: ", newLine = false)
    var path: DirectoryPath = "exit".DirectoryPath
    while path.len > 0:
      path = ($readInput()).DirectoryPath
      if path.len > 0 and not dirExists(dir = $path) and path != "exit":
        showError(message = "Please enter a path to the existing directory")
        showOutput(message = "Path: ", newLine = false)
      else:
        break
    if path == "exit":
      return showError(message = "Editing the variable cancelled.")
    elif path == "":
      path = row[1].DirectoryPath
    # Set the recursiveness for the variable
    showFormHeader(message = "(4/5) Recursiveness", db = db)
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
    # Set the value for the variable
    showFormHeader(message = "(5/5) Value", db = db)
    showOutput(message = "The value of the variable. Current value: '",
        newLine = false)
    showOutput(message = row[2], newLine = false, fgColor = fgMagenta)
    showOutput(message = "'. Value can't contain a new line character.:")
    var value: UserInput = readInput()
    if value == "exit":
      return showError(message = "Editing the variable cancelled.")
    elif value == "":
      try:
        value.text = row[2]
      except CapacityError:
        return showError(message = "Editing the variable cancelled. Reason: can't set value for the variable.")
    # Save the variable to the database
    try:
      if db.execAffectedRows(query = sql(
          query = "UPDATE variables SET name=?, path=?, recursive=?, value=?, description=? where id=?"),
           args = [$name, $path, $recursive, $value, $description, $varId]) != 1:
        return showError(message = "Can't edit the variable.")
    except DbError:
      return showError(message = "Can't save the edits of the variable to database. Reason: ",
          e = getCurrentException())
    try:
      setVariables(newDirectory = getCurrentDirectory().DirectoryPath, db = db,
          oldDirectory = getCurrentDirectory().DirectoryPath)
    except OSError:
      return showError(message = "Can't set variables for the current directory. Reason: ",
          e = getCurrentException())
    showOutput(message = "The variable  with Id: '" & $varId & "' edited.",
        fgColor = fgGreen)
    return QuitSuccess.ResultCode

proc createVariablesDb*(db): ResultCode {.gcsafe, sideEffect, raises: [],
    tags: [WriteDbEffect, ReadDbEffect, WriteIOEffect, RootEffect],
    contractual.} =
  ## Create the table variables
  ##
  ## * db - the connection to the shell's database
  ##
  ## Returns QuitSuccess if creation was successfull, otherwise QuitFailure and
  ## show message what wrong
  require:
    db != nil
  body:
    try:
      db.createTables(obj = newVariable())
    except:
      return showError(message = "Can't create 'variables' table. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc initVariables*(db; commands: ref CommandsList) {.sideEffect,
    raises: [], tags: [ReadDbEffect, WriteEnvEffect, WriteIOEffect,
    ReadEnvEffect, TimeEffect, WriteDbEffect, RootEffect], contractual.} =
  ## Initialize enviroment variables. Set help related to the variables and
  ## load the local environment variables.
  ##
  ## * helpContent - the HelpTable with help content of the shell
  ## * db          - the connection to the shell's database
  ## * commands    - the list of the shell's commands
  ##
  ## Returns the list of available environment variables in the current directory and
  ## the updated helpContent with the help for the commands related to the
  ## variables.
  require:
    db != nil
  body:
    # Add commands related to the variables, except commands set and unset,
    # they are build-in commands, thus cannot be replaced
    proc variableCommand(arguments: UserInput; db;
        list: CommandLists): ResultCode {.raises: [], tags: [WriteIOEffect,
        WriteDbEffect, TimeEffect, ReadDbEffect, ReadIOEffect, ReadEnvEffect,
        RootEffect], contractual.} =
      ## The code of the shell's command "variable" and its subcommands
      ##
      ## * arguments - the arguments entered by the user for the command
      ## * db        - the connection to the shell's database
      ## * list      - the additional data for the command, like list of help
      ##               entries, etc
      ##
      ## Returns QuitSuccess if the selected command was successfully executed,
      ## otherwise QuitFailure.
      body:
        # No subcommand entered, show available options
        if arguments.len == 0:
          return showHelpList(command = "variable",
              subcommands = variablesCommands)
        # Show the list of declared environment variables
        if arguments.startsWith(prefix = "list"):
          return listVariables(arguments = arguments, db = db)
        # Delete the selected environment variable
        if arguments.startsWith(prefix = "delete"):
          return deleteVariable(arguments = arguments, db = db)
        # Add a new variable
        if arguments == "add":
          return addVariable(db = db)
        # Edit an existing variable
        if arguments.startsWith(prefix = "edit"):
          return editVariable(arguments = arguments, db = db)
        try:
          return showUnknownHelp(subCommand = arguments,
              command = initLimitedString(capacity = 8, text = "variable"),
              helpType = initLimitedString(capacity = 9, text = "variables"))
        except CapacityError:
          return QuitFailure.ResultCode

    try:
      addCommand(name = initLimitedString(capacity = 8, text = "variable"),
          command = variableCommand, commands = commands)
    except CapacityError, CommandsListError:
      showError(message = "Can't add commands related to the shell's variables system. Reason: ",
          e = getCurrentException())
    # Set the environment variables for the current directory
    try:
      setVariables(newDirectory = getCurrentDirectory().DirectoryPath, db = db)
    except OSError:
      showError(message = "Can't set environment variables for the current directory. Reason:",
          e = getCurrentException())

