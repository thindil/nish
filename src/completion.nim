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
import std/[os, strutils, tables]
# External modules imports
import contracts
import norm/[model, pragmas, sqlite]
# Internal imports
import commandslist, constants, lstring, options, output, resultcode

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

const completionCommands*: array[5, string] = ["list", "delete", "show", "add", "edit"]
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
        return QuitSuccess.ResultCode
        # No subcommand entered, show available options
      #        if arguments.len == 0:
      #          return showHelpList(command = "completion",
      #              subcommands = aliasesCommands)
      #        # Show the list of available aliases
      #        if arguments.startsWith(prefix = "list"):
      #          return listCompletion(arguments = arguments, aliases = aliases, db = db)
      #        # Delete the selected alias
      #        if arguments.startsWith(prefix = "delete"):
      #          return deleteCompletion(arguments = arguments, aliases = aliases, db = db)
      #        # Show the selected alias
      #        if arguments.startsWith(prefix = "show"):
      #          return showCompletion(arguments = arguments, db = db)
      #        # Add a new alias
      #        if arguments.startsWith(prefix = "add"):
      #          return addCompletion(aliases = aliases, db = db)
      #        # Edit the selected alias
      #        if arguments.startsWith(prefix = "edit"):
      #          return editCompletion(arguments = arguments, aliases = aliases, db = db)
      #        try:
      #          return showUnknownHelp(subCommand = arguments,
      #              command = initLimitedString(capacity = 10, text = "completion"),
      #                  helpType = initLimitedString(capacity = 7,
      #                      text = "aliases"))
      #        except CapacityError:
      #          return QuitFailure.ResultCode

    try:
      addCommand(name = initLimitedString(capacity = 10, text = "completion"),
          command = completionCommand, commands = commands)
    except CapacityError, CommandsListError:
      showError(message = "Can't add commands related to the shell's completion system. Reason: ",
          e = getCurrentException())
