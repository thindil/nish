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

## This module contains code related to the completion with Tab key the user's
## input, like completing names of files, directories, commands, etc.

# Standard library imports
import std/[os, strutils, tables, terminal]
# External modules imports
import contracts
import norm/[model, pragmas, sqlite]
# Internal imports
import commandslist, constants, help, input, lstring, options, output, resultcode

type
  CompletionType = enum
    ## Used to set the type of commands' completion
    dirs, files, dirsfiles, commands, custom, none

  Completion* {.tableName: "completions".} = ref object of Model
    ## Data structure for the shell's commands' completion
    ##
    ## * command - the command for which the completion is set
    ## * cType   - the type of completion for the command
    ## * values  - the proper values of completion if the completion's type is
    ##             set to the custom type
    command* {.unique.}: string
    cType*: CompletionType
    cValues*: string

const completionCommands*: array[7, string] = ["list", "delete", "show", "add",
    "edit", "import", "export"]
  ## The list of available subcommands for command completion

using db: DbConn # Connection to the shell's database

proc dbType*(T: typedesc[CompletionType]): string {.raises: [], tags: [],
    contractual.} =
  ## Set the type of field in the database
  ##
  ## * T - the type for which the field will be set
  ##
  ## Returns the type of the field in the database
  body:
    "TEXT"

proc dbValue*(val: CompletionType): DbValue {.raises: [], tags: [],
    contractual.} =
  ## Convert the type of the option's value to database field
  ##
  ## * val - the value to convert
  ##
  ## Returns the converted val parameter
  body:
    dbValue(v = $val)

proc to*(dbVal: DbValue, T: typedesc[CompletionType]): T {.raises: [], tags: [],
    contractual.} =
  ## Convert the value from the database to enumeration
  ##
  ## * dbVal - the value to convert
  ## * T     - the type to which the value will be converted
  ##
  ## Returns the converted dbVal parameter
  body:
    try:
      parseEnum[CompletionType](s = dbVal.s)
    except:
      none

proc newCompletion*(command: string = ""; cType: CompletionType = none;
    cValues: string = ""): Completion {.raises: [], tags: [], contractual.} =
  ## Create a new data structure for the shell's completion option.
  ##
  ## * command - the name of the command for which the completion is
  ## * cType   - the type of the completion
  ## * cValues - the values for the completion if the completion's type is custom
  ##
  ## Returns the new data structure for the selected shell's commmand's
  ## completion.
  body:
    Completion(command: command, cType: cType, cValues: cValues)

proc getDirCompletion*(prefix: string; completions: var seq[string];
    db) {.sideEffect, raises: [], tags: [ReadDirEffect, WriteIOEffect,
    ReadDbEffect, ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Get the relative path of file or directory, based on the selected prefix
  ## in the current directory.
  ##
  ## * prefix      - the prefix which will be looking for in the current directory
  ## * completions - the list of completions for the current prefix
  ##
  ## Returns the updated completions parameter with additional entries of relative
  ## paths to the files or directories which match the parameter prefix. If
  ## prefix is empty, or there is no matching file or directory, returns the
  ## same completion parameter.
  body:
    if prefix.len == 0:
      return
    let completionAmount: int = try:
        parseInt(s = $getOption(optionName = initLimitedString(
          capacity = 16, text = "completionAmount"), db = db,
          defaultValue = initLimitedString(capacity = 2, text = "30")))
      except ValueError, CapacityError:
        30
    # Completion disabled
    if completionAmount == 0:
      return
    let caseSensitive: bool = try:
        parseBool(s = $getOption(optionName = initLimitedString(
          capacity = 19, text = "completionCheckCase"), db = db,
          defaultValue = initLimitedString(capacity = 5, text = "false")))
      except ValueError, CapacityError:
        true
    try:
      if caseSensitive:
        for item in walkPattern(pattern = prefix & "*"):
          if completions.len >= completionAmount:
            return
          let completion: string = (if dirExists(dir = item): item &
              DirSep else: item)
          if completion notin completions:
            completions.add(y = completion)
      else:
        let prefixInsensitive: string = prefix.lastPathPart.toLowerAscii
        var parentDir: string = (if prefix.parentDir ==
              ".": "" else: prefix.parentDir & DirSep)
        if prefix.endsWith(suffix = DirSep):
          parentDir = prefix
        for item in walkDir(dir = parentDir.absolutePath, relative = true):
          if completions.len >= completionAmount:
            return
          var completion: string = (if dirExists(dir = item.path): item.path &
              DirSep else: item.path)
          if (completion.toLowerAscii.startsWith(prefix = prefixInsensitive) or
              prefix.endsWith(suffix = DirSep)) and completion notin completions:
            completions.add(y = parentDir & completion)
    except:
      showError(message = "Can't get completion. Reason: ",
          e = getCurrentException())

proc getCommandCompletion*(prefix: string; completions: var seq[string];
    aliases: ref AliasesList; commands: ref CommandsList; db) {.sideEffect,
    raises: [], tags: [ReadEnvEffect, ReadDirEffect, ReadDbEffect,
    ReadEnvEffect, TimeEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Get the list of available commands which starts with the selected prefix
  ##
  ## * prefix      - the prefix which will be looking for in commands
  ## * completions - the list of completions for the current prefix
  ## * aliases     - the list of available shell's aliases
  ## * commands    - the list of the shell's commands
  ##
  ## Returns the updated completions parameter with additional entries of commands
  ## which match the parameter prefix. If prefix is empty, or there is no
  ## matching file or directory, returns unchanged completion parameter.
  body:
    if prefix.len == 0:
      return
    let completionAmount: int = try:
        parseInt(s = $getOption(optionName = initLimitedString(
          capacity = 16, text = "completionAmount"), db = db,
          defaultValue = initLimitedString(capacity = 2, text = "30")))
      except ValueError, CapacityError:
        30
    # Completion disabled
    if completionAmount == 0:
      return
    # Check built-in commands
    for command in builtinCommands:
      if completions.len >= completionAmount:
        return
      if command.startsWith(prefix = prefix) and command notin completions:
        completions.add(y = command)
    # Check for all shell's commands
    for command in commands.keys:
      if completions.len >= completionAmount:
        return
      if command.startsWith(prefix = prefix) and command notin completions:
        completions.add(y = command)
    # Check the shell's aliases
    for alias in aliases.keys:
      if completions.len >= completionAmount:
        return
      if alias.startsWith(prefix = prefix) and $alias notin completions:
        completions.add(y = $alias)
    # Check for programs and commands in the system
    try:
      for path in getEnv(key = "PATH").split(sep = PathSep):
        for file in walkFiles(pattern = path & DirSep & prefix & "*"):
          if completions.len >= completionAmount:
            return
          let fileName: string = file.extractFilename
          if fileName notin completions:
            completions.add(y = fileName)
    except OSError:
      return

proc createCompletionDb*(db): ResultCode {.sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Create the table completions
  ##
  ## * db - the connection to the shell's database
  ##
  ## Returns QuitSuccess if creation was successfull, otherwise QuitFailure and
  ## show message what wrong
  require:
    db != nil
  body:
    try:
      db.createTables(obj = newCompletion())
    except:
      return showError(message = "Can't create 'completions' table. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc addCompletion*(db): ResultCode {.sideEffect, raises: [],
    tags: [ReadDbEffect, ReadIOEffect, WriteIOEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Add a new commands' completion to the shell. Ask the user a few questions and fill the
  ## completion values with answers
  ##
  ## * db      - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the new completion was properly set, otherwise QuitFailure.
  require:
    db != nil
  body:
    showOutput(message = "You can cancel adding a new completion at any time by double press Escape key or enter word 'exit' as an answer.")
    # Set the name for the alias
    showFormHeader(message = "(1/2 or 3) Command", db = db)
    showOutput(message = "The command for which the completion will be. Will be used to find the completion in the shell's database. For example: 'ls'. Can't be empty:")
    showOutput(message = "Command: ", newLine = false)
    var command: LimitedString = emptyLimitedString(capacity = maxInputLength)
    while command.len == 0:
      command = readInput(maxLength = maxInputLength)
      if command.len == 0:
        showError(message = "Please enter a name for the command.")
      if command.len == 0:
        showOutput(message = "Command: ", newLine = false)
    if command == "exit":
      return showError(message = "Adding a new completion cancelled.")
    # Set the description for the alias
    showFormHeader(message = "(2/2 or 3) Type", db = db)
    showOutput(message = "The type of the completion. It determines what values will be suggested for the completion. If type 'custom' will be selected, you will need also enter a list of the values for the completion. Possible values are: ")
    showOutput(message = "d) Directories only")
    showOutput(message = "Description: ", newLine = false)
    let description: UserInput = readInput()
    if description == "exit":
      return showError(message = "Adding a new completion cancelled.")
#    # Set the working directory for the alias
#    showFormHeader(message = "(3/6) Working directory", db = db)
#    showOutput(message = "The full path to the directory in which the alias will be available. If you want to have a global alias, set it to '/'. Can't be empty and must be a path to the existing directory.: ")
#    showOutput(message = "Path: ", newLine = false)
#    var path: DirectoryPath = "".DirectoryPath
#    while path.len == 0:
#      path = ($readInput()).DirectoryPath
#      if path.len == 0:
#        showError(message = "Please enter a path for the alias.")
#      elif not dirExists(dir = $path) and path != "exit":
#        path = "".DirectoryPath
#        showError(message = "Please enter a path to the existing directory")
#      if path.len == 0:
#        showOutput(message = "Path: ", newLine = false)
#    if path == "exit":
#      return showError(message = "Adding a new alias cancelled.")
#    # Set the recursiveness for the alias
#    showFormHeader(message = "(4/6) Recursiveness", db = db)
#    showOutput(message = "Select if alias is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press 'y' or 'n':")
#    showOutput(message = "Recursive(y/n): ", newLine = false)
#    var inputChar: char = try:
#        getch()
#      except IOError:
#        'y'
#    while inputChar notin {'n', 'N', 'y', 'Y'}:
#      inputChar = try:
#        getch()
#      except IOError:
#        'y'
#    showOutput(message = $inputChar)
#    let recursive: BooleanInt = if inputChar in {'n', 'N'}: 0 else: 1
#    # Set the commands to execute for the alias
#    showFormHeader(message = "(5/6) Commands", db = db)
#    showOutput(message = "The commands which will be executed when the alias is invoked. If you want to execute more than one command, you can merge them with '&&' or '||'. For example: 'clear && ls -a'. Commands can't contain a new line character. Can't be empty.:")
#    showOutput(message = "Command(s): ", newLine = false)
#    var commands: UserInput = emptyLimitedString(capacity = maxInputLength)
#    while commands.len == 0:
#      commands = readInput()
#      if commands.len == 0:
#        showError(message = "Please enter commands for the alias.")
#        showOutput(message = "Command(s): ", newLine = false)
#    if commands == "exit":
#      return showError(message = "Adding a new alias cancelled.")
#    # Set the destination for the alias' output
#    showFormHeader(message = "(6/6) Output", db = db)
#    showOutput(message = "Where should be redirected the alias output. Possible values are stdout (standard output, default), stderr (standard error) or path to the file to which output will be append. For example: 'output.txt'.:")
#    showOutput(message = "Output to: ", newLine = false)
#    var output: UserInput = readInput()
#    if output == "exit":
#      return showError(message = "Adding a new alias cancelled.")
#    elif output == "":
#      try:
#        output.text = "stdout"
#      except CapacityError:
#        return showError(message = "Adding a new alias cancelled. Reason: Can't set output for the alias")
#    var alias: Alias = newAlias(name = $name, path = $path,
#        recursive = recursive == 1, commands = $commands,
#        description = $description, output = $output)
#    # Check if alias with the same parameters exists in the database
#    try:
#      if db.exists(T = Alias, cond = "name=?", params = alias.name):
#        return showError(message = "There is an alias with the same name in the database.")
#    except:
#      return showError(message = "Can't check if the similar alias exists. Reason: ",
#          e = getCurrentException())
#    # Save the alias to the database
#    try:
#      db.insert(obj = alias)
#    except:
#      return showError(message = "Can't add the alias to the database. Reason: ",
#          e = getCurrentException())
#    # Refresh the list of available aliases
#    try:
#      aliases.setAliases(directory = getCurrentDirectory().DirectoryPath, db = db)
#    except OSError:
#      return showError(message = "Can't set aliases for the current directory. Reason: ",
#          e = getCurrentException())
    showOutput(message = "The new completion for the command '" & command & "' added.",
        fgColor = fgGreen)
    return QuitSuccess.ResultCode

proc initCompletion*(db; commands: ref CommandsList) {.sideEffect, raises: [],
    tags: [WriteIOEffect, RootEffect], contractual.} =
  ## Initialize the shell's completion system. Set help related to the
  ## completion
  ##
  ## * db       - the connection to the shell's database
  ## * commands - the list of the shell's commands
  ##
  ## Returns the updated list of the shell's commands.
  require:
    db != nil
  body:
    # Add commands related to the shell's completion's system
    proc completionCommand(arguments: UserInput; db;
        list: CommandLists): ResultCode {.raises: [], tags: [WriteIOEffect,
        WriteDbEffect, TimeEffect, ReadDbEffect, ReadIOEffect, ReadEnvEffect,
        RootEffect], contractual.} =
      ## The code of the shell's command "alias" and its subcommands
      ##
      ## * arguments - the arguments entered by the user for the command
      ## * db        - the connection to the shell's database
      ## * list      - the additional data for the command, like id of alias, etc
      ##
      ## Returns QuitSuccess if the selected command was successfully executed,
      ## otherwise QuitFailure.
      body:
        # No subcommand entered, show available options
        if arguments.len == 0:
          return showHelpList(command = "completion",
              subcommands = completionCommands)
           # Add a new completion
        if arguments.startsWith(prefix = "add"):
          return addCompletion(db = db)
      #        # Show the list of available completions
      #        if arguments.startsWith(prefix = "list"):
      #          return listCompletion(arguments = arguments, aliases = aliases, db = db)
      #        # Delete the selected completion
      #        if arguments.startsWith(prefix = "delete"):
      #          return deleteCompletion(arguments = arguments, aliases = aliases, db = db)
      #        # Show the selected completion
      #        if arguments.startsWith(prefix = "show"):
      #          return showCompletion(arguments = arguments, db = db)
      #        # Edit the selected completion
      #        if arguments.startsWith(prefix = "edit"):
      #          return editCompletion(arguments = arguments, aliases = aliases, db = db)
        try:
          return showUnknownHelp(subCommand = arguments,
              command = initLimitedString(capacity = 10, text = "completion"),
                  helpType = initLimitedString(capacity = 11,
                      text = "completions"))
        except CapacityError:
          return QuitFailure.ResultCode

    try:
      addCommand(name = initLimitedString(capacity = 10, text = "completion"),
          command = completionCommand, commands = commands)
    except CapacityError, CommandsListError:
      showError(message = "Can't add commands related to the shell's completion system. Reason: ",
          e = getCurrentException())
