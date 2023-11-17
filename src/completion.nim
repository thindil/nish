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
import contracts, nancy, termstyle
import norm/[model, pragmas, sqlite]
# Internal imports
import commandslist, constants, databaseid, help, input, lstring, options,
    output, resultcode

type
  CompletionType = enum
    ## Used to set the type of commands' completion
    dirs = "Directories only", files = "Files only",
        dirsfiles = "Directories and files", commands = "Commands",
        custom = "Custom",
        none = "Completion for the selected command should be disabled"

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

using
  db: DbConn # Connection to the shell's database
  arguments: UserInput # The string with arguments entered by the user for the command

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
    # Set the command for the completion
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
    # Set the type for the completion
    showFormHeader(message = "(2/2 or 3) Type", db = db)
    showOutput(message = "The type of the completion. It determines what values will be suggested for the completion. If type 'custom' will be selected, you will need also enter a list of the values for the completion. The default option is disabling completion. Possible values are: ")
    showOutput(message = "d) " & $dirs)
    showOutput(message = "f) " & $files)
    showOutput(message = "a) " & $dirsfiles)
    showOutput(message = "c) " & $commands)
    showOutput(message = "u) " & $custom)
    showOutput(message = "n) " & $CompletionType.none)
    showOutput(message = "q) Stop adding the completion")
    showOutput(message = "Type (d/f/a/c/u/n/q): ")
    var typeChar: char = try:
        getch()
      except IOError:
        'n'
    while typeChar.toLowerAscii notin {'d', 'f', 'a', 'c', 'u', 'n', 'q'}:
      typeChar = try:
        getch()
      except IOError:
        'n'
    if typeChar == 'q':
      return showError(message = "Adding a new completion cancelled.")
    var values: UserInput = emptyLimitedString(capacity = maxInputLength)
    # Set the values for the completion if the user selected custom type of completion
    if typeChar == 'u':
      showFormHeader(message = "(3/3) Values", db = db)
      showOutput(message = "The values for the completion, separated by semicolon. Values can't contain a new line character. Can't be empty.:")
      showOutput(message = "Value(s): ", newLine = false)
      while values.len == 0:
        values = readInput()
        if values.len == 0:
          showError(message = "Please enter values for the completion.")
          showOutput(message = "Value(s): ", newLine = false)
      if values == "exit":
        return showError(message = "Adding a new completion cancelled.")
    var completion: Completion = newCompletion(command = $command, cType = (
        case typeChar.toLowerAscii
        of 'd':
          dirs
        of 'f':
          files
        of 'a':
          dirsfiles
        of 'c':
          commands
        of 'u':
          custom
        else:
          none), cValues = $values)
    # Check if completion with the same parameters exists in the database
    try:
      if db.exists(T = Completion, cond = "command=?",
          params = completion.command):
        return showError(message = "There is a completion for the same command in the database.")
    except:
      return showError(message = "Can't check if the similar completion exists. Reason: ",
          e = getCurrentException())
    # Save the completion to the database
    try:
      db.insert(obj = completion)
    except:
      return showError(message = "Can't add the completion to the database. Reason: ",
          e = getCurrentException())
    showOutput(message = "The new completion for the command '" & command &
        "' added.", fgColor = fgGreen)
    return QuitSuccess.ResultCode

proc editCompletion*(arguments; db): ResultCode {.sideEffect, raises: [],
    tags: [ReadDbEffect, ReadIOEffect, WriteIOEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Edit the selected alias
  ##
  ## * arguments - the user entered text with arguments for the editing alias
  ## * aliases   - the list of aliases available in the current directory
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the alias was properly edited, otherwise
  ## QuitFailure. Also, updated parameter aliases.
  require:
    arguments.len > 3
    db != nil
  body:
    var
      completion: Completion = newCompletion()
      id: DatabaseId = 0.DatabaseId
    if arguments.len < 6:
      return showError(message = "Enter the ID of the completion to edit.")
    try:
      id = parseInt(s = $arguments[5 .. ^1]).DatabaseId
    except ValueError:
      return showError(message = "The Id of the completion must be a positive number.")
    try:
      db.select(obj = completion, cond = "id=?", params = $id)
    except:
      return showError(message = "Can't check if the completion exists.")
    if completion.command.len == 0:
      return showError(message = "The completion with the Id: " & $id &
        " doesn't exists.")
    showOutput(message = "You can cancel editing the completion at any time by double press Escape key or enter word 'exit' as an answer. You can also reuse a current value by leaving an answer empty.")
    # Set the command for the completion
    showFormHeader(message = "(1/2 or 3) Command", db = db)
    showOutput(message = "The command for which the completion will be. Will be used to find the completion in the shell's database. Current value: '",
        newLine = false)
    showOutput(message = completion.command, newLine = false,
        fgColor = fgMagenta)
    showOutput(message = "'.")
    showOutput(message = "Command: ", newLine = false)
    var command: LimitedString = readInput(maxLength = maxInputLength)
    if command == "exit":
      return showError(message = "Editing the completion cancelled.")
    elif command == "":
      try:
        command.text = completion.command
      except CapacityError:
        return showError(message = "Editing the completion cancelled. Reason: Can't set command for the completion")
    # Set the type for the completion
    showFormHeader(message = "(2/2 or 3) Type", db = db)
    showOutput(message = "The type of the completion. It determines what values will be suggested for the completion. If type 'custom' will be selected, you will need also enter a list of the values for the completion. The current value is: '",
        newLine = false)
    showOutput(message = $completion.cType, newLine = false,
        fgColor = fgMagenta)
    showOutput(message = "'. Possible values are:")
    showOutput(message = "d) " & $dirs)
    showOutput(message = "f) " & $files)
    showOutput(message = "a) " & $dirsfiles)
    showOutput(message = "c) " & $commands)
    showOutput(message = "u) " & $custom)
    showOutput(message = "n) " & $CompletionType.none)
    showOutput(message = "q) Stop adding the completion")
    showOutput(message = "Type (d/f/a/c/u/n/q): ")
    var typeChar: char = try:
        getch()
      except IOError:
        'n'
    while typeChar.toLowerAscii notin {'d', 'f', 'a', 'c', 'u', 'n', 'q'}:
      typeChar = try:
        getch()
      except IOError:
        'n'
    let completionType: CompletionType = case typeChar.toLowerAscii
        of 'd':
          dirs
        of 'f':
          files
        of 'a':
          dirsfiles
        of 'c':
          commands
        of 'u':
          custom
        else:
          none
    try:
      stdout.writeLine(x = "")
    except IOError:
      discard
    var values: UserInput = emptyLimitedString(capacity = maxInputLength)
    # Set the values for the completion if the user selected custom type of completion
    if typeChar == 'u':
      showFormHeader(message = "(3/3) Values", db = db)
      showOutput(message = "The values for the completion, separated by semicolon. Values can't contain a new line character. The current value is: '",
          newLine = false)
      showOutput(message = completion.cValues, newLine = false,
          fgColor = fgMagenta)
      showOutput(message = "'.")
      showOutput(message = "Value(s): ", newLine = false)
      while values.len == 0:
        values = readInput()
        if values.len == 0:
          showError(message = "Please enter values for the completion.")
          showOutput(message = "Value(s): ", newLine = false)
      if values == "exit":
        return showError(message = "Editing the existing completion cancelled.")
    # Save the completion to the database
    try:
      completion.command = $command
      completion.cType = completionType
      completion.cValues = $values
      db.update(obj = completion)
    except:
      return showError(message = "Can't update the completion. Reason: ",
          e = getCurrentException())
    showOutput(message = "The completion with Id: '" & $id & "' edited.",
        fgColor = fgGreen)
    return QuitSuccess.ResultCode

proc listCompletion*(arguments; db): ResultCode {.sideEffect, raises: [],
    tags: [ReadIOEffect, WriteIOEffect, ReadDbEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## List all available commands' completions.
  ##
  ## * arguments - the user entered text with arguments for showing completions
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the list of completion was shown, otherwise QuitFailure
  require:
    arguments.len > 3
    arguments.startsWith(prefix = "list")
    db != nil
  body:
    var table: TerminalTable = TerminalTable()
    try:
      table.add(parts = [magenta(ss = "ID"), magenta(ss = "Command"), magenta(
          ss = "Type")])
    except:
      return showError(message = "Can't show commands list. Reason: ",
          e = getCurrentException())
    var dbCompletions: seq[Completion] = @[newCompletion()]
    try:
      db.selectAll(objs = dbCompletions)
    except:
      return showError(message = "Can't read info about alias from database. Reason:",
          e = getCurrentException())
    if dbCompletions.len == 0:
      showOutput(message = "There are no defined commands' completions.")
      return QuitSuccess.ResultCode
    try:
      for dbResult in dbCompletions:
        table.add(parts = [yellow(ss = dbResult.id), green(
            ss = dbResult.command), $dbResult.cType])
    except:
      return showError(message = "Can't add a completion to the list. Reason:",
          e = getCurrentException())
    try:
      var width: int = 0
      for size in table.getColumnSizes(maxSize = int.high):
        width = width + size + 2
      showFormHeader(message = "Available completions are:",
          width = width.ColumnAmount, db = db)
      table.echoTable
    except:
      return showError(message = "Can't show the list of aliases. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc deleteCompletion*(arguments; db): ResultCode {.sideEffect, raises: [],
    tags: [WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Delete the selected completion from the shell's database
  ##
  ## * arguments - the user entered text with arguments for the deleting completion
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the selected completion was properly deleted, otherwise
  ## QuitFailure.
  require:
    arguments.len > 5
    arguments.startsWith(prefix = "delete")
    db != nil
  body:
    if arguments.len < 8:
      return showError(message = "Enter the Id of the completion to delete.")
    let id: DatabaseId = try:
        parseInt(s = $arguments[7 .. ^1]).DatabaseId
      except ValueError:
        return showError(message = "The Id of the completion must be a positive number.")
    try:
      if not db.exists(T = Completion, cond = "id=?", params = $id):
        return showError(message = "The completion with the Id: " & $id &
          " doesn't exists.")
    except:
      return showError(message = "Can't find the completion in database. Reason: ",
          e = getCurrentException())
    try:
      var completion: Completion = newCompletion()
      db.select(obj = completion, cond = "id=?", params = $id)
      db.delete(obj = completion)
    except:
      return showError(message = "Can't delete completion from database. Reason: ",
          e = getCurrentException())
    showOutput(message = "Deleted the completion with Id: " & $id, fgColor = fgGreen)
    return QuitSuccess.ResultCode

proc showCompletion*(arguments; db): ResultCode {.sideEffect, raises: [], tags: [
    WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect, ReadEnvEffect,
    TimeEffect, RootEffect], contractual.} =
  ## Show details about the selected completion, its ID, command, type and
  ## values if the type is custon
  ##
  ## * arguments - the user entered text with arguments for the showing completion
  ## * db        - the connection to the shell's database
  ##
  ## Returns quitSuccess if the selected completion was properly show, otherwise
  ## QuitFailure.
  require:
    arguments.len > 3
    arguments.startsWith(prefix = "show")
    db != nil
  body:
    if arguments.len < 6:
      return showError(message = "Enter the ID of the completion to show.")
    let id: DatabaseId = try:
        parseInt(s = $arguments[5 .. ^1]).DatabaseId
      except:
        return showError(message = "The Id of the completion must be a positive number.")
    var completion: Completion = newCompletion()
    try:
      if not db.exists(T = Completion, cond = "id=?", params = $id):
        return showError(message = "The completion with the ID: " & $id &
          " doesn't exists.")
      db.select(obj = completion, cond = "id=?", params = $id)
    except:
      return showError(message = "Can't read completion data from database. Reason: ",
          e = getCurrentException())
    var table: TerminalTable = TerminalTable()
    try:
      table.add(parts = [magenta(ss = "Id:"), $id])
      table.add(parts = [magenta(ss = "Command:"), completion.command])
      table.add(parts = [magenta(ss = "Type:"), $completion.cType])
      if completion.cType == custom:
        table.add(parts = [magenta(ss = "Values:"), completion.cValues])
      table.echoTable
    except:
      return showError(message = "Can't show completion. Reason: ",
          e = getCurrentException())
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
        # Edit the selected completion
        if arguments.startsWith(prefix = "edit"):
          return editCompletion(arguments = arguments, db = db)
        # Show the list of available completions
        if arguments.startsWith(prefix = "list"):
          return listCompletion(arguments = arguments, db = db)
        # Delete the selected completion
        if arguments.startsWith(prefix = "delete"):
          return deleteCompletion(arguments = arguments, db = db)
        # Show the selected completion
        if arguments.startsWith(prefix = "show"):
          return showCompletion(arguments = arguments, db = db)
        # TODO: import command
        # TODO: export command
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
