# Copyright © 2022-2024 Bartek Jasicki
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
import std/[os, strutils, tables]
# External modules imports
import ansiparse, contracts, nancy, nimalyzer, termstyle
import norm/[model, sqlite]
# Internal imports
import commandslist, constants, databaseid, directorypath, help, input, lstring,
    output, resultcode, theme

const
  variableNameLength*: Positive = maxNameLength
    ## The maximum length of the shell's environment variable name
  variablesCommands: seq[string] = @["list", "delete", "add", "edit", "show"]
    ## The list of available subcommands for command variable
  variablesOptions: Table[char, string] = {'p': "path", 't': "text",
      'n': "number", 'q': "quit"}.toTable
    ## The list of available options when setting the type of a variable's value

type VariableName = LimitedString
    ## Used to store variables names in the database.

using
  db: DbConn # Connection to the shell's database
  arguments: UserInput # The string with arguments entered by the user for the command

proc dbType*(T: typedesc[VariableValType]): string {.raises: [], tags: [],
    contractual.} =
  ## Set the type of field in the database
  ##
  ## * T - the type for which the field will be set
  ##
  ## Returns the type of the field in the database
  body:
    "TEXT"

proc dbValue*(val: VariableValType): DbValue {.raises: [], tags: [],
    contractual.} =
  ## Convert the type of the variable's value to database field
  ##
  ## * val - the value to convert
  ##
  ## Returns the converted val parameter
  body:
    dbValue(v = $val)

proc to*(dbVal: DbValue, T: typedesc[VariableValType]): T {.raises: [], tags: [
    ], contractual.} =
  ## Convert the value from the database to enumeration
  ##
  ## * dbVal - the value to convert
  ## * T     - the type to which the value will be converted
  ##
  ## Returns the converted dbVal parameter
  body:
    try:
      parseEnum[VariableValType](s = dbVal.s)
    except:
      text

proc buildQuery*(directory: DirectoryPath; fields: string = "";
    where: string = ""): string {.sideEffect, raises: [], tags: [ReadDbEffect],
    contractual.} =
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
    var skipped: seq[int64] = @[]

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
            e = getCurrentException(), db = db)
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
          e = getCurrentException(), db = db)

proc setCommand*(arguments; db): ResultCode {.sideEffect, raises: [], tags: [
    ReadIOEffect, ReadDbEffect, WriteIOEffect, WriteDbEffect, ReadEnvEffect,
    TimeEffect, RootEffect], contractual.} =
  ## Build-in command to set the selected environment variable
  ##
  ## * arguments - the user entered text with arguments for set variable
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the environment variable was successfully set, otherwise
  ## QuitFailure
  body:
    if arguments.len == 0:
      return showError(message = "You have to enter the name of the variable and its value.", db = db)
    let varValues: seq[string] = split(s = $arguments, sep = '=')
    if varValues.len < 2:
      return showError(message = "You have to enter the name of the variable and its value.", db = db)
    try:
      putEnv(key = varValues[0], val = varValues[1])
      showOutput(message = "Environment variable '" & varValues[0] &
          "' set to '" & varValues[1] & "'", color = success, db = db)
      return QuitSuccess.ResultCode
    except OSError:
      return showError(message = "Can't set the environment variable '" &
          varValues[0] & "'. Reason:", e = getCurrentException(), db = db)

proc unsetCommand*(arguments; db): ResultCode {.sideEffect, raises: [], tags: [
    ReadIOEffect, ReadDbEffect, WriteIOEffect, WriteDbEffect, ReadEnvEffect,
    TimeEffect, RootEffect], contractual.} =
  ## Build-in command to unset the selected environment variable
  ##
  ## * arguments - the user entered text with arguments for unset variable
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the environment variable was successfully unset, otherwise
  ## QuitFailure
  body:
    if arguments.len == 0:
      return showError(message = "You have to enter the name of the variable to unset.", db = db)
    try:
      delEnv(key = $arguments)
      showOutput(message = "Environment variable '" & arguments & "' removed",
          color = success, db = db)
      return QuitSuccess.ResultCode
    except OSError:
      return showError(message = "Can't unset the environment variable '" &
          arguments & "'. Reason:", e = getCurrentException(), db = db)

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
      let color: string = getColor(db = db, name = tableHeaders)
      table.add(parts = [style(ss = "ID", style = color), style(ss = "Name",
          style = color), style(ss = "Value", style = color)])
    except UnknownEscapeError, InsufficientInputError, FinalByteError:
      return showError(message = "Can't show variables list. Reason: ",
          e = getCurrentException(), db = db)
    # Show the list of all declared environment variables in the shell
    if arguments == "list all":
      try:
        db.selectAll(objs = variables)
        if variables.len == 0:
          showOutput(message = "There are no defined shell's environment variables.", db = db)
          return QuitSuccess.ResultCode
        for variable in variables:
          table.add(parts = [style(ss = variable.id, style = getColor(db = db,
              name = ids)), style(ss = variable.name, style = getColor(db = db,
              name = values)), style(ss = variable.value, style = getColor(
              db = db, name = default))])
      except:
        return showError(message = "Can't read data about variables from database. Reason: ",
            e = getCurrentException(), db = db)
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
          showOutput(message = "There are no defined shell's environment variables in this directory.", db = db)
          return QuitSuccess.ResultCode
        for variable in variables:
          table.add(parts = [style(ss = variable.id, style = getColor(db = db,
              name = ids)), style(ss = variable.name, style = getColor(db = db,
              name = values)), style(ss = variable.value, style = getColor(
              db = db, name = default))])
      except:
        return showError(message = "Can't get the current directory name. Reason: ",
            e = getCurrentException(), db = db)
      var width: int = 0
      for size in table.getColumnSizes(maxSize = int.high):
        width = width + size
      showFormHeader(message = "Declared environent variables are:",
          width = width.ColumnAmount, db = db)
    try:
      table.echoTable
    except IOError, Exception:
      return showError(message = "Can't show the list of declared shell's environment variables. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc getVariableId*(arguments; db): DatabaseId {.sideEffect, raises: [], tags: [
    WriteIOEffect, TimeEffect, ReadDbEffect, ReadIOEffect, RootEffect],
    contractual.} =
  ## Get the ID of the variable. If the user didn't enter the ID, show the list of
  ## variables and ask the user for ID. Otherwise, check correctness of entered
  ## ID.
  ##
  ## * arguments - the user entered text with arguments for a command
  ## * db        - the connection to the shell's database
  ##
  ## Returns the ID of a variable or 0 if entered ID was invalid or the user
  ## decided to cancel the command.
  require:
    db != nil
    arguments.len > 0
  body:
    result = 0.DatabaseId
    var
      variable: Variable = newVariable()
      actionName: string = ""
      argumentsLen: Positive = 1
    if arguments.startsWith(prefix = "delete"):
      actionName = "Deleting"
      argumentsLen = 8
    elif arguments.startsWith(prefix = "show"):
      actionName = "Showing"
      argumentsLen = 6
    elif arguments.startsWith(prefix = "edit"):
      actionName = "Editing"
      argumentsLen = 6
    if arguments.len < argumentsLen:
      askForName[Variable](db = db, action = actionName & " a variable",
            namesType = "variable", name = variable)
      if variable.description.len == 0:
        return 0.DatabaseId
      return variable.id.DatabaseId
    result = try:
        parseInt(s = $arguments[argumentsLen - 1 .. ^1]).DatabaseId
      except ValueError:
        showError(message = "The Id of the variable must be a positive number.", db = db)
        return 0.DatabaseId
    try:
      if not db.exists(T = Variable, cond = "id=?", params = $result):
        showError(message = "The variable with the Id: " & $result &
            " doesn't exists.", db = db)
        return 0.DatabaseId
    except:
      showError(message = "Can't find the variable in database. Reason: ",
          e = getCurrentException(), db = db)
      return 0.DatabaseId

proc deleteVariable*(arguments; db): ResultCode {.sideEffect, raises: [],
    tags: [WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect,
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
    let id: DatabaseId = getVariableId(arguments = arguments, db = db)
    if id.Natural == 0:
      return QuitFailure.ResultCode
    try:
      var variable: Variable = newVariable()
      db.select(obj = variable, cond = "id=?", params = $id)
      db.delete(obj = variable)
    except:
      return showError(message = "Can't delete variable from database. Reason: ",
          e = getCurrentException(), db = db)
    try:
      setVariables(newDirectory = getCurrentDirectory().DirectoryPath, db = db,
          oldDirectory = getCurrentDirectory().DirectoryPath)
    except OSError:
      return showError(message = "Can't set environment variables in the current directory. Reason: ",
          e = getCurrentException(), db = db)
    showOutput(message = "Deleted the variable with Id: " & $id,
        color = success, db = db)
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
    showOutput(message = "You can cancel adding a new variable at any time by double press Escape key or enter word 'exit' as an answer.", db = db)
    # Set the name for the variable
    showFormHeader(message = "(1/6) Name", db = db)
    showOutput(message = "The name of the variable. For example: 'MY_KEY'. Can't be empty and can contains only letters, numbers and underscores:", db = db)
    var
      variable: Variable = newVariable()
      name: VariableName = emptyLimitedString(capacity = variableNameLength)
    showOutput(message = "Name: ", newLine = false, db = db)
    while name.len == 0:
      name = readInput(maxLength = variableNameLength, db = db)
      if name.len == 0:
        showError(message = "Please enter a name for the variable.", db = db)
      elif not validIdentifier(s = $name):
        try:
          name.text = ""
          showError(message = "Please enter a valid name for the variable.", db = db)
        except CapacityError:
          showError(message = "Can't set empty name for variable.", db = db)
      if name.len == 0:
        showOutput(message = "Name: ", newLine = false, db = db)
    if name == "exit":
      return showError(message = "Adding a new variable cancelled.", db = db)
    variable.name = $name
    # Set the description for the variable
    showFormHeader(message = "(2/6) Description", db = db)
    showOutput(message = "The description of the variable. It will be show on the list of available variables. For example: 'My key to database.'. Can't contains a new line character.: ", db = db)
    showOutput(message = "Description: ", newLine = false, db = db)
    let description: UserInput = readInput(db = db)
    if description == "exit":
      return showError(message = "Adding a new variable cancelled.", db = db)
    variable.description = $description
    # Set the working directory for the variable
    showFormHeader(message = "(3/6) Working directory", db = db)
    showOutput(message = "The full path to the directory in which the variable will be available. If you want to have a global variable, set it to '/'. Can't be empty and must be a path to the existing directory.: ", db = db)
    showOutput(message = "Path: ", newLine = false, db = db)
    var path: DirectoryPath = "".DirectoryPath
    while path.len == 0:
      path = ($readInput(db = db)).DirectoryPath
      if path.len == 0:
        showError(message = "Please enter a path for the alias.", db = db)
      elif not dirExists(dir = $path) and path != "exit":
        path = "".DirectoryPath
        showError(message = "Please enter a path to the existing directory", db = db)
      if path.len == 0:
        showOutput(message = "Path: ", newLine = false, db = db)
    if path == "exit":
      return showError(message = "Adding a new variable cancelled.", db = db)
    variable.path = $path
    # Set the recursiveness for the variable
    showFormHeader(message = "(4/6) Recursiveness", db = db)
    showOutput(message = "Select if variable is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press 'y' or 'n':", db = db)
    let recursive: BooleanInt = if confirm(prompt = "Recursive",
        db = db): 1 else: 0
    try:
      stdout.writeLine(x = "")
    except IOError:
      discard
    variable.recursive = recursive == 1
    # Set the type of for the variable's value
    showFormHeader(message = "(5/6) Value's type", db = db)
    showOutput(message = "The type of the value of the variable. Used to check its correctness during adding or editing the variable.", db = db)
    var inputChar: char = selectOption(options = variablesOptions,
        default = 't', prompt = "Type", db = db)
    try:
      case inputChar
      of 'p':
        variable.varType = path
      of 't':
        variable.varType = text
      of 'n':
        variable.varType = number
      of 'q':
        return showError(message = "Adding a variable cancelled.", db = db)
      else:
        discard
    except CapacityError:
      return showError(message = "Adding a variable cancelled. Reason: Can't set type of the value for the selected variable", db = db)
    # Set the value for the variable
    showFormHeader(message = "(6/6) Value", db = db)
    showOutput(message = "The value of the variable. For example: 'mykeytodatabase'. Value can't contain a new line character. Can't be empty.:", db = db)
    showOutput(message = "Value: ", newLine = false, db = db)
    var value: UserInput = emptyLimitedString(capacity = maxInputLength)
    while value.len == 0:
      value = readInput(db = db)
      if value.len == 0:
        showError(message = "Please enter value for the variable.", db = db)
        showOutput(message = "Value: ", newLine = false, db = db)
      if variable.varType == VariableValType.path and not dirExists(dir = $value):
        showError(message = "Path '" & value & "' doesn't exist.", db = db)
        showOutput(message = "Value: ", newLine = false, db = db)
        value = emptyLimitedString(capacity = maxInputLength)
      elif variable.varType == number:
        try:
          discard parseInt(s = $value)
        except:
          showError(message = "The selected value isn't a number.", db = db)
          showOutput(message = "Value: ", newLine = false, db = db)
          value = emptyLimitedString(capacity = maxInputLength)
    if value == "exit":
      return showError(message = "Adding a new variable cancelled.", db = db)
    variable.value = $value
    # Check if variable with the same parameters exists in the database
    try:
      if db.exists(T = Variable, cond = "name=? AND path=? AND recursive=? AND value=?",
          params = [($name).dbValue, ($path).dbValue, ($recursive).dbValue, (
          $value).dbValue]):
        return showError(message = "There is a variable with the same name, path and value in the database.", db = db)
    except:
      return showError(message = "Can't check if the same variable exists in the database. Reason: ",
          e = getCurrentException(), db = db)
    # Save the variable to the database
    try:
      db.insert(obj = variable)
    except:
      return showError(message = "Can't add the variable to database. Reason: ",
          e = getCurrentException(), db = db)
    try:
      setVariables(newDirectory = getCurrentDirectory().DirectoryPath, db = db)
    except OSError:
      return showError(message = "Can't set variables for the current directory. Reason: ",
          e = getCurrentException(), db = db)
    showOutput(message = "The new variable '" & name & "' added.",
        color = success, db = db)
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
    let id: DatabaseId = getVariableId(arguments = arguments, db = db)
    if id.Natural == 0:
      return QuitFailure.ResultCode
    var variable: Variable = newVariable()
    try:
      db.select(obj = variable, cond = "id=?", params = $id)
    except:
      return showError(message = "Can't get the selected variable from the database. Reason:",
          e = getCurrentException(), db = db)
    showOutput(message = "You can cancel editing the variable at any time by double press Escape key or enter word 'exit' as an answer. You can also reuse a current value by pressing Enter.", db = db)
    # Set the name for the variable
    showFormHeader(message = "(1/6) Name", db = db)
    showOutput(message = "The name of the variable. Current value: '",
        newLine = false, db = db)
    showOutput(message = variable.name, newLine = false, color = values, db = db)
    showOutput(message = "'. Can contains only letters, numbers and underscores.:", db = db)
    var name: VariableName = try:
        initLimitedString(capacity = variableNameLength, text = "exit")
      except CapacityError:
        return showError(message = "Can't set name of the variable", db = db)
    showOutput(message = "Name: ", newLine = false, db = db)
    while name.len > 0:
      name = readInput(maxLength = variableNameLength, db = db)
      if name.len > 0 and not validIdentifier(s = $name):
        showError(message = "Please enter a valid name for the variable.", db = db)
        showOutput(message = "Name: ", newLine = false, db = db)
      else:
        break
    if name == "exit":
      return showError(message = "Editing the variable cancelled.", db = db)
    elif name == "":
      try:
        name.text = variable.name
      except CapacityError:
        return showError(message = "Editing the variable cancelled. Reason: can't set name for the variable.", db = db)
    variable.name = $name
    # Set the description for the variable
    showFormHeader(message = "(2/6) Description", db = db)
    showOutput(message = "The description of the variable. It will be show on the list of available variable. Current value: '",
        newLine = false, db = db)
    showOutput(message = variable.description, newLine = false,
        color = values, db = db)
    showOutput(message = "'. Can't contains a new line character.: ", db = db)
    var description: UserInput = readInput(db = db)
    if description == "exit":
      return showError(message = "Editing the variable cancelled.", db = db)
    elif description == "":
      try:
        description.text = variable.description
      except CapacityError:
        return showError(message = "Editing the variable cancelled. Reason: can't set description for the variable.", db = db)
    variable.description = $description
    # Set the working directory for the variable
    showFormHeader(message = "(3/6) Working directory", db = db)
    showOutput(message = "The full path to the directory in which the variable will be available. If you want to have a global variable, set it to '/'. Current value: '",
        newLine = false, db = db)
    showOutput(message = variable.path, newLine = false, color = values, db = db)
    showOutput(message = "'. Must be a path to the existing directory.:", db = db)
    showOutput(message = "Path: ", newLine = false, db = db)
    var path: DirectoryPath = "exit".DirectoryPath
    while path.len > 0:
      path = ($readInput(db = db)).DirectoryPath
      if path.len > 0 and not dirExists(dir = $path) and path != "exit":
        showError(message = "Please enter a path to the existing directory", db = db)
        showOutput(message = "Path: ", newLine = false, db = db)
      else:
        break
    if path == "exit":
      return showError(message = "Editing the variable cancelled.", db = db)
    elif path == "":
      path = variable.path.DirectoryPath
    variable.path = $path
    # Set the recursiveness for the variable
    showFormHeader(message = "(4/6) Recursiveness", db = db)
    showOutput(message = "Select if variable is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press 'y' or 'n':", db = db)
    let recursive: BooleanInt = if confirm(prompt = "Recursive",
        db = db): 1 else: 0
    try:
      stdout.writeLine(x = "")
    except IOError:
      discard
    variable.recursive = recursive == 1
    # Set the type of for the variable's value
    showFormHeader(message = "(5/6) Value's type", db = db)
    showOutput(message = "The type of the value of the variable. Used to check its correctness during adding or editing the variable. Current value: '",
        newLine = false, db = db)
    showOutput(message = $variable.varType, newLine = false, color = values, db = db)
    showOutput(message = "'.:", db = db)
    var inputChar: char = selectOption(options = variablesOptions,
        default = 't', prompt = "Type", db = db)
    try:
      case inputChar
      of 'p':
        variable.varType = path
      of 't':
        variable.varType = text
      of 'n':
        variable.varType = number
      of 'q':
        return showError(message = "Editing the variable cancelled.", db = db)
      else:
        discard
    except CapacityError:
      return showError(message = "Editing the variable cancelled. Reason: Can't set type of the value for the selected variable", db = db)
    # Set the value for the variable
    showFormHeader(message = "(6/6) Value", db = db)
    showOutput(message = "The value of the variable. Current value: '",
        newLine = false, db = db)
    showOutput(message = variable.value, newLine = false, color = values, db = db)
    showOutput(message = "'. Value can't contain a new line character.:", db = db)
    var value: UserInput = try:
        initLimitedString(capacity = maxInputLength, text = "invalid")
      except:
        return showError(message = "Editing the variable cancelled. Can't set the variable's value.", db = db)
    while value == "invalid":
      value = readInput(db = db)
      if value.len == 0:
        break
      if variable.varType == VariableValType.path and not dirExists(dir = $value):
        showError(message = "Path '" & value & "' doesn't exist.", db = db)
        showOutput(message = "Value: ", newLine = false, db = db)
        try:
          value.text = "invalid"
        except:
          discard
      elif variable.varType == number:
        try:
          discard parseInt(s = $value)
        except:
          showError(message = "The selected value isn't a number.", db = db)
          showOutput(message = "Value: ", newLine = false, db = db)
          try:
            value.text = "invalid"
          except:
            discard
    if value == "exit":
      return showError(message = "Editing the variable cancelled.", db = db)
    elif value.len == 0:
      try:
        value.text = variable.value
      except CapacityError:
        return showError(message = "Editing the variable cancelled. Reason: can't set value for the variable.", db = db)
    variable.value = $value
    # Save the variable to the database
    try:
      db.update(obj = variable)
    except:
      return showError(message = "Can't save the edits of the variable to database. Reason: ",
          e = getCurrentException(), db = db)
    try:
      setVariables(newDirectory = getCurrentDirectory().DirectoryPath, db = db)
    except OSError:
      return showError(message = "Can't set variables for the current directory. Reason: ",
          e = getCurrentException(), db = db)
    showOutput(message = "The variable with Id: '" & $id & "' edited.",
        color = success, db = db)
    return QuitSuccess.ResultCode

proc showVariable*(arguments; db): ResultCode {.sideEffect, raises: [], tags: [
    WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect, ReadEnvEffect,
    TimeEffect, RootEffect], contractual.} =
  ## Show details about the selected variable, its ID, name, description and
  ## its path
  ##
  ## * arguments - the user entered text with arguments for the showing variable
  ## * db        - the connection to the shell's database
  ##
  ## Returns quitSuccess if the selected variable was properly show, otherwise
  ## QuitFailure.
  require:
    arguments.len > 3
    arguments.startsWith(prefix = "show")
    db != nil
  body:
    let id: DatabaseId = getVariableId(arguments = arguments, db = db)
    if id.Natural == 0:
      return QuitFailure.ResultCode
    var variable: Variable = newVariable()
    try:
      db.select(obj = variable, cond = "id=?", params = $id)
    except:
      return showError(message = "Can't read variable data from database. Reason: ",
          e = getCurrentException(), db = db)
    var table: TerminalTable = TerminalTable()
    try:
      let
        color: string = getColor(db = db, name = showHeaders)
        color2: string = getColor(db = db, name = default)
      table.add(parts = [style(ss = "Id:", style = color), style(ss = $id,
          style = color2)])
      table.add(parts = [style(ss = "Name:", style = color), style(
          ss = variable.name, style = color2)])
      table.add(parts = [style(ss = "Type:", style = color), style(
          ss = $variable.varType, style = color2)])
      table.add(parts = [style(ss = "Value:", style = color), style(
          ss = variable.value, style = color2)])
      table.add(parts = [style(ss = "Description:", style = color), style(ss = (
          if variable.description.len > 0: variable.description else: "(none)"),
          style = color2)])
      table.add(parts = [style(ss = "Path:", style = color), style(
          ss = variable.path & (if variable.recursive: " (recursive)" else: ""),
              style = color2)])
      table.echoTable
    except:
      return showError(message = "Can't show variable. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc createVariablesDb*(db): ResultCode {.sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect, RootEffect], contractual.} =
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
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc updateVariablesDb*(db): ResultCode {.sideEffect,
    raises: [], tags: [WriteDbEffect, ReadDbEffect, WriteIOEffect, RootEffect],
    contractual.} =
  ## Update the table variables to the new version if needed
  ##
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if update was successfull, otherwise QuitFailure and
  ## show message what's wrong
  require:
    db != nil
  body:
    try:
      db.exec(query = sql(query = """ALTER TABLE variables ADD varType TEXT NOT NULL DEFAULT 'text'"""))
    except:
      return showError(message = "Can't update table for the shell's variables. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc initVariables*(db; commands: ref CommandsList) {.sideEffect,
    raises: [], tags: [ReadDbEffect, WriteEnvEffect, WriteIOEffect,
    ReadEnvEffect, TimeEffect, WriteDbEffect, RootEffect], contractual.} =
  ## Initialize enviroment variables. Set help related to the variables and
  ## load the local environment variables.
  ##
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
              subcommands = variablesCommands, db = db)
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
        # Show an existing variable
        if arguments.startsWith(prefix = "show"):
          return showVariable(arguments = arguments, db = db)
        try:
          return showUnknownHelp(subCommand = arguments,
              command = initLimitedString(capacity = 8, text = "variable"),
              helpType = initLimitedString(capacity = 9, text = "variables"), db = db)
        except CapacityError:
          return QuitFailure.ResultCode

    try:
      addCommand(name = initLimitedString(capacity = 8, text = "variable"),
          command = variableCommand, commands = commands,
          subCommands = variablesCommands)
    except CapacityError, CommandsListError:
      showError(message = "Can't add commands related to the shell's variables system. Reason: ",
          e = getCurrentException(), db = db)
    # Set the environment variables for the current directory
    try:
      setVariables(newDirectory = getCurrentDirectory().DirectoryPath, db = db)
    except OSError:
      showError(message = "Can't set environment variables for the current directory. Reason:",
          e = getCurrentException(), db = db)

