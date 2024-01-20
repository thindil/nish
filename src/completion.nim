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

## This module contains code related to the completion with Tab key the user's
## input, like completing names of files, directories, commands, etc.

# Standard library imports
import std/[os, parsecfg, strutils, tables]
# External modules imports
import contracts, nancy, nimalyzer, termstyle
import norm/[model, sqlite]
# Internal imports
import commandslist, constants, databaseid, help, input, options,
    output, resultcode, theme

type DirCompletionType = enum
  ## Used to set the type of completion for directories and files
  dirs, files, all

const
  completionCommands: seq[string] = @["list", "delete", "show", "add",
    "edit", "import", "export"]
    ## The list of available subcommands for command completion
  completionOptions: Table[char, string] = {'d': $CompletionType.dirs,
      'f': $CompletionType.files, 'a': $dirsfiles, 'c': $commands, 'u': $custom,
      'n': $CompletionType.none, 'q': "quit"}.toTable
    ## The list of available options when setting the type of a completion

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
    "INTEGER"

proc dbValue*(val: CompletionType): DbValue {.raises: [], tags: [],
    contractual.} =
  ## Convert the type of the option's value to database field
  ##
  ## * val - the value to convert
  ##
  ## Returns the converted val parameter
  body:
    dbValue(v = val.ord)

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
      dbVal.i.CompletionType
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

proc getDirCompletion*(prefix: string; completions: var seq[string]; db;
    cType: DirCompletionType = all) {.sideEffect, raises: [], tags: [
    ReadDirEffect, WriteIOEffect, ReadDbEffect, ReadEnvEffect, TimeEffect,
    RootEffect], contractual.} =
  ## Get the relative path of file or directory, based on the selected prefix
  ## in the current directory.
  ##
  ## * prefix      - the prefix which will be looking for in the current directory
  ## * completions - the list of completions for the current prefix
  ## * db          - the connection to the shell's database
  ## * cType       - what kind of items will be looking for. Default value is all,
  ##                 files and directories
  ##
  ## Returns the updated completions parameter with additional entries of relative
  ## paths to the files or directories which match the parameter prefix. If
  ## prefix is empty, or there is no matching file or directory, returns the
  ## same completion parameter.
  body:
    if prefix.len == 0:
      return
    let completionAmount: int = try:
        parseInt(s = $getOption(optionName = "completionAmount", db = db,
          defaultValue = "30"))
      except:
        30
    # Completion disabled
    if completionAmount == 0:
      return
    let caseSensitive: bool = try:
        parseBool(s = $getOption(optionName = "completionCheckCase", db = db,
          defaultValue = "false"))
      except:
        true
    try:
      if caseSensitive:
        for item in walkPattern(pattern = prefix & "*"):
          if completions.len >= completionAmount:
            return
          if (cType == files and not fileExists(filename = item)) or (cType ==
              dirs and not dirExists(dir = item)):
            continue
          let completion: string = (if dirExists(dir = item): item &
              DirSep else: item)
          if completion notin completions:
            completions.add(y = completion)
      else:
        let prefixInsensitive: string = prefix.lastPathPart.toLowerAscii
        var parentDir: string = case prefix.parentDir
          of ".":
            ""
          of "/":
            "/"
          else:
            prefix.parentDir & DirSep
        if prefix.endsWith(suffix = DirSep):
          parentDir = prefix
        for item in walkDir(dir = parentDir.absolutePath, relative = true):
          if completions.len >= completionAmount:
            return
          if (cType == files and not fileExists(filename = parentDir &
              item.path)) or (cType == dirs and not dirExists(dir = parentDir & item.path)):
            continue
          var completion: string = (if dirExists(dir = parentDir &
              item.path): item.path & DirSep else: item.path)
          if (completion.toLowerAscii.startsWith(prefix = prefixInsensitive) or
              prefix.endsWith(suffix = DirSep)) and completion notin completions:
            completions.add(y = parentDir & completion)
    except:
      showError(message = "Can't get completion. Reason: ",
          e = getCurrentException(), db = db)

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
  ## * db          - the connection to the shell's database
  ##
  ## Returns the updated completions parameter with additional entries of commands
  ## which match the parameter prefix. If prefix is empty, or there is no
  ## matching file or directory, returns unchanged completion parameter.
  body:
    if prefix.len == 0:
      return
    let completionAmount: int = try:
        parseInt(s = $getOption(optionName = "completionAmount", db = db,
          defaultValue = "30"))
      except:
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

proc getCompletion*(commandName, prefix: string; completions: var seq[string];
    aliases: ref AliasesList; commands: ref CommandsList; db) {.sideEffect,
    raises: [], tags: [ReadDirEffect, WriteIOEffect, ReadDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Get the completion for the selected command from the shell's completion
  ## database, based on the selected prefix
  ##
  ## * commandName - the name of the command for which the completions will
  ##                 be looked for
  ## * prefix      - the prefix which will be looking for in the database
  ## * completions - the list of completions for the current prefix
  ## * aliases     - the list of available shell's aliases
  ## * commands    - the list of the shell's commands
  ## * db          - the connection to the shell's database
  ##
  ## Returns the updated completions parameter with additional entries for
  ## completions, which match the parameter prefix. If prefix is empty, or
  ## there is no matching entries, returns the same completion parameter.
  body:
    if prefix.len == 0:
      return
    let completionAmount: int = try:
        parseInt(s = $getOption(optionName = "completionAmount", db = db,
          defaultValue = "30"))
      except:
        30
    # Completion disabled
    if completionAmount == 0:
      return
    var completion: Completion = newCompletion()
    # Get the completion for the selected command from database
    try:
      db.select(obj = completion, cond = "command=?", params = commandName)
    except:
      # Get the completion for the shell's built-in commands
      if commands.hasKey(key = commandName):
        completions = @[]
        try:
          for command in commands[commandName].subcommands:
            if command.startsWith(prefix = prefix) and command notin completions:
              completions.add(y = command)
        except:
          return
      return
    completions = @[]
    case completion.cType
    of dirs:
      getDirCompletion(prefix = prefix, completions = completions, db = db, cType = dirs)
    of files:
      getDirCompletion(prefix = prefix, completions = completions, db = db, cType = files)
    of dirsfiles:
      getDirCompletion(prefix = prefix, completions = completions, db = db)
    of commands:
      getCommandCompletion(prefix = prefix, completions = completions,
          aliases = aliases, commands = commands, db = db)
    of custom:
      for value in completion.cValues.split(sep = ';'):
        if value.startsWith(prefix = prefix) and value notin completions:
          completions.add(y = value)
    of none:
      discard

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
          e = getCurrentException(), db = db)
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
    showOutput(message = "You can cancel adding a new completion at any time by double press Escape key or enter word 'exit' as an answer.", db = db)
    # Set the command for the completion
    showFormHeader(message = "(1/2 or 3) Command", db = db)
    showOutput(message = "The command for which the completion will be. Will be used to find the completion in the shell's database. For example: 'ls'. Can't be empty:", db = db)
    showOutput(message = "Command: ", newLine = false, db = db)
    var command: UserInput = ""
    while command.len == 0:
      command = readInput(maxLength = maxInputLength, db = db)
      if command.len == 0:
        showError(message = "Please enter a name for the command.", db = db)
      if command.len == 0:
        showOutput(message = "Command: ", newLine = false, db = db)
    if command == "exit":
      return showError(message = "Adding a new completion cancelled.", db = db)
    # Set the type for the completion
    showFormHeader(message = "(2/2 or 3) Type", db = db)
    showOutput(message = "The type of the completion. It determines what values will be suggested for the completion. If type 'custom' will be selected, you will need also enter a list of the values for the completion. The default option is disabling completion. Possible values are: ", db = db)
    let typeChar: char = selectOption(options = completionOptions,
        default = 'n', prompt = "Type", db = db)
    if typeChar == 'q':
      return showError(message = "Adding a new completion cancelled.", db = db)
    var values: UserInput = ""
    # Set the values for the completion if the user selected custom type of completion
    if typeChar == 'u':
      showFormHeader(message = "(3/3) Values", db = db)
      showOutput(message = "The values for the completion, separated by semicolon. Values can't contain a new line character. Can't be empty.:", db = db)
      showOutput(message = "Value(s): ", newLine = false, db = db)
      while values.len == 0:
        values = readInput(db = db)
        if values.len == 0:
          showError(message = "Please enter values for the completion.", db = db)
          showOutput(message = "Value(s): ", newLine = false, db = db)
      if values == "exit":
        return showError(message = "Adding a new completion cancelled.", db = db)
    var completion: Completion = newCompletion(command = $command, cType = (
        case typeChar.toLowerAscii
          of 'd':
            CompletionType.dirs
          of 'f':
            CompletionType.files
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
        return showError(message = "There is a completion for the same command in the database.", db = db)
    except:
      return showError(message = "Can't check if the similar completion exists. Reason: ",
          e = getCurrentException(), db = db)
    # Save the completion to the database
    try:
      db.insert(obj = completion)
    except:
      return showError(message = "Can't add the completion to the database. Reason: ",
          e = getCurrentException(), db = db)
    showOutput(message = "The new completion for the command '" & command &
        "' added.", color = success, db = db)
    return QuitSuccess.ResultCode

proc getCompletionId*(arguments; db): DatabaseId {.sideEffect, raises: [],
    tags: [WriteIOEffect, TimeEffect, ReadDbEffect, ReadIOEffect, RootEffect],
    contractual.} =
  ## Get the ID of the completion. If the user didn't enter the ID, show the list of
  ## completions and ask the user for ID. Otherwise, check correctness of entered
  ## ID.
  ##
  ## * arguments - the user entered text with arguments for a command
  ## * db        - the connection to the shell's database
  ##
  ## Returns the ID of a completion or 0 if entered ID was invalid or the user
  ## decided to cancel the command.
  require:
    db != nil
    arguments.len > 0
  body:
    result = 0.DatabaseId
    var
      completion: Completion = newCompletion()
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
      askForName[Completion](db = db, action = actionName & " a completion",
            namesType = "completion", name = completion)
      if completion.command.len == 0:
        return 0.DatabaseId
      return completion.id.DatabaseId
    result = try:
        parseInt(s = $arguments[argumentsLen - 1 .. ^1]).DatabaseId
      except ValueError:
        showError(message = "The Id of the completion must be a positive number.", db = db)
        return 0.DatabaseId
    try:
      if not db.exists(T = Completion, cond = "id=?", params = $result):
        showError(message = "The completion with the Id: " & $result &
            " doesn't exists.", db = db)
        return 0.DatabaseId
    except:
      showError(message = "Can't find the completion in database. Reason: ",
          e = getCurrentException(), db = db)
      return 0.DatabaseId

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
    let id: DatabaseId = getCompletionId(arguments = arguments, db = db)
    if id.Natural == 0:
      return QuitFailure.ResultCode
    var completion: Completion = newCompletion()
    try:
      db.select(obj = completion, cond = "id=?", params = $id)
    except:
      return showError(message = "Can't get completion from the database. Reason: ",
          e = getCurrentException(), db = db)
    showOutput(message = "You can cancel editing the completion at any time by double press Escape key or enter word 'exit' as an answer. You can also reuse a current value by leaving an answer empty.", db = db)
    # Set the command for the completion
    showFormHeader(message = "(1/2 or 3) Command", db = db)
    showOutput(message = "The command for which the completion will be. Will be used to find the completion in the shell's database. Current value: '",
        newLine = false, db = db)
    showOutput(message = completion.command, newLine = false,
        color = values, db = db)
    showOutput(message = "'.", db = db)
    showOutput(message = "Command: ", newLine = false, db = db)
    var command: UserInput = readInput(maxLength = maxInputLength, db = db)
    if command == "exit":
      return showError(message = "Editing the completion cancelled.", db = db)
    elif command == "":
      command = completion.command
    # Set the type for the completion
    showFormHeader(message = "(2/2 or 3) Type", db = db)
    showOutput(message = "The type of the completion. It determines what values will be suggested for the completion. If type 'custom' will be selected, you will need also enter a list of the values for the completion. The current value is: '",
        newLine = false, db = db)
    showOutput(message = $completion.cType, newLine = false,
        color = values, db = db)
    showOutput(message = "'. Possible values are:", db = db)
    let typeChar: char = selectOption(options = completionOptions,
        default = 'n', prompt = "Type", db = db)
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
    var values: UserInput = ""
    # Set the values for the completion if the user selected custom type of completion
    if typeChar == 'u':
      showFormHeader(message = "(3/3) Values", db = db)
      showOutput(message = "The values for the completion, separated by semicolon. Values can't contain a new line character. The current value is: '",
          newLine = false, db = db)
      showOutput(message = completion.cValues, newLine = false,
          color = ThemeColor.values, db = db)
      showOutput(message = "'.", db = db)
      showOutput(message = "Value(s): ", newLine = false, db = db)
      while values.len == 0:
        values = readInput(db = db)
        if values.len == 0:
          showError(message = "Please enter values for the completion.", db = db)
          showOutput(message = "Value(s): ", newLine = false, db = db)
      if values == "exit":
        return showError(message = "Editing the existing completion cancelled.", db = db)
    # Save the completion to the database
    try:
      completion.command = $command
      completion.cType = completionType
      completion.cValues = $values
      db.update(obj = completion)
    except:
      return showError(message = "Can't update the completion. Reason: ",
          e = getCurrentException(), db = db)
    showOutput(message = "The completion with Id: '" & $id & "' edited.",
        color = success, db = db)
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
      let color: string = getColor(db = db, name = tableHeaders)
      table.add(parts = [style(ss = "ID", style = color), style(ss = "Command",
          style = color), style(ss = "Type", style = color)])
    except:
      return showError(message = "Can't show commands list. Reason: ",
          e = getCurrentException(), db = db)
    var dbCompletions: seq[Completion] = @[newCompletion()]
    try:
      db.selectAll(objs = dbCompletions)
    except:
      return showError(message = "Can't read info about alias from database. Reason:",
          e = getCurrentException(), db = db)
    if dbCompletions.len == 0:
      showOutput(message = "There are no defined commands' completions.", db = db)
      return QuitSuccess.ResultCode
    try:
      for dbResult in dbCompletions:
        table.add(parts = [style(ss = dbResult.id, style = getColor(db = db,
            name = ids)), style(ss = dbResult.command, style = getColor(db = db,
            name = values)), style(ss = $dbResult.cType, style = getColor(
            db = db, name = default))])
    except:
      return showError(message = "Can't add a completion to the list. Reason:",
          e = getCurrentException(), db = db)
    try:
      var width: int = 0
      for size in table.getColumnSizes(maxSize = int.high):
        width = width + size + 2
      showFormHeader(message = "Available completions are:",
          width = width.ColumnAmount, db = db)
      table.echoTable
    except:
      return showError(message = "Can't show the list of aliases. Reason: ",
          e = getCurrentException(), db = db)
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
    let id: DatabaseId = getCompletionId(arguments = arguments, db = db)
    if id.Natural == 0:
      return QuitFailure.ResultCode
    try:
      var completion: Completion = newCompletion()
      db.select(obj = completion, cond = "id=?", params = $id)
      db.delete(obj = completion)
    except:
      return showError(message = "Can't delete completion from database. Reason: ",
          e = getCurrentException(), db = db)
    showOutput(message = "Deleted the completion with Id: " & $id,
        color = success, db = db)
    return QuitSuccess.ResultCode

proc showCompletion*(arguments; db): ResultCode {.sideEffect, raises: [],
    tags: [WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect,
        ReadEnvEffect,
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
    let id: DatabaseId = getCompletionId(arguments = arguments, db = db)
    if id.Natural == 0:
      return QuitFailure.ResultCode
    var completion: Completion = newCompletion()
    try:
      db.select(obj = completion, cond = "id=?", params = $id)
    except:
      return showError(message = "Can't read completion data from database. Reason: ",
          e = getCurrentException(), db = db)
    var table: TerminalTable = TerminalTable()
    try:
      let
        color: string = getColor(db = db, name = showHeaders)
        color2: string = getColor(db = db, name = default)
      table.add(parts = [style(ss = "Id:", style = color), style(ss = $id,
          style = color2)])
      table.add(parts = [style(ss = "Command:", style = color),
          style(ss = completion.command, style = color2)])
      table.add(parts = [style(ss = "Type:", style = color), style(
          ss = $completion.cType, style = color2)])
      if completion.cType == custom:
        table.add(parts = [style(ss = "Values:", style = color),
            style(ss = completion.cValues, style = color2)])
      table.echoTable
    except:
      return showError(message = "Can't show completion. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc exportCompletion*(arguments; db): ResultCode {.sideEffect, raises: [],
    tags: [WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect,
        ReadEnvEffect,
    TimeEffect, RootEffect], contractual.} =
  ## Export the selected completion, to the text file
  ##
  ## * arguments - the user entered text with arguments for exporting the completion
  ## * db        - the connection to the shell's database
  ##
  ## Returns quitSuccess if the selected completion was properly exported to the
  ## file, otherwise QuitFailure.
  require:
    arguments.len > 5
    arguments.startsWith(prefix = "export")
    db != nil
  body:
    if arguments.len < 7:
      return showError(message = "Enter the ID of the completion to export and the name of the file where it will be saved.", db = db)
    let args: seq[string] = split(s = $arguments, sep = ' ')
    if args.len < 3:
      return showError(message = "Enter the ID of the completion to export and the name of the file where it will be saved.", db = db)
    let
      id: DatabaseId = try:
          args[1].parseInt.DatabaseId
        except:
          return showError(message = "The Id of the completion must be a positive number.", db = db)
      fileName: string = args[2 .. ^1].join(sep = " ")
    var completion: Completion = newCompletion()
    try:
      if not db.exists(T = Completion, cond = "id=?", params = $id):
        return showError(message = "The completion with the ID: " & $id &
          " doesn't exists.", db = db)
      db.select(obj = completion, cond = "id=?", params = $id)
    except:
      return showError(message = "Can't read completion data from database. Reason: ",
          e = getCurrentException(), db = db)
    var dict: Config = newConfig()
    try:
      dict.setSectionKey(section = "", key = "Command",
          value = completion.command)
      dict.setSectionKey(section = "", key = "Type", value = $completion.cType)
      if completion.cValues.len > 0:
        dict.setSectionKey(section = "", key = "Values",
            value = completion.cValues)
      dict.writeConfig(filename = fileName)
    except:
      return showError(message = "Can't create the completion export file. Reason: ",
          e = getCurrentException(), db = db)
    showOutput(message = "Exported the completion with Id: " & $id &
        " to file: " & $fileName, color = success, db = db)
    return QuitSuccess.ResultCode

proc importCompletion*(arguments; db): ResultCode {.sideEffect, raises: [],
    tags: [WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect,
        ReadEnvEffect,
    TimeEffect, RootEffect], contractual.} =
  ## Import a completion from the text file
  ##
  ## * arguments - the user entered text with arguments for exporting the completion
  ## * db        - the connection to the shell's database
  ##
  ## Returns quitSuccess if the selected completion was properly imported to the
  ## shell, otherwise QuitFailure.
  require:
    arguments.len > 5
    arguments.startsWith(prefix = "import")
    db != nil
  body:
    if arguments.len < 7:
      return showError(message = "Enter the name of the file with the completion.", db = db)
    let fileName: string = $arguments[7 .. ^1]
    try:
      let
        dict: Config = loadConfig(filename = fileName)
        command: string = dict.getSectionValue(section = "", key = "Command")
      try:
        if db.exists(T = Completion, cond = "command=?", params = command):
          return showError(message = "The completion for the command: " &
            command & " exists.", db = db)
      except:
        return showError(message = "Can't check completion in database. Reason: ",
            e = getCurrentException(), db = db)
      var completion: Completion = newCompletion(command = dict.getSectionValue(
          section = "", key = "Command"), cType = parseEnum[CompletionType](
          s = dict.getSectionValue(section = "", key = "Type")),
          cValues = dict.getSectionValue(section = "", key = "Values"))
      db.insert(obj = completion)
    except:
      return showError(message = "Can't import the completion from the file. Reason: ",
          e = getCurrentException(), db = db)
    showOutput(message = "Imported the completion from file : " & fileName,
        color = success, db = db)
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
              subcommands = completionCommands, db = db)
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
        # Import a completion from the file
        if arguments.startsWith(prefix = "import"):
          return importCompletion(arguments = arguments, db = db)
        # Export the selected completion to the file
        if arguments.startsWith(prefix = "export"):
          return exportCompletion(arguments = arguments, db = db)
        return showUnknownHelp(subCommand = arguments,
            command = "completion",
                helpType = "completions", db = db)

    try:
      addCommand(name = "completion",
          command = completionCommand, commands = commands,
          subCommands = completionCommands)
    except:
      showError(message = "Can't add commands related to the shell's completion system. Reason: ",
          e = getCurrentException(), db = db)
