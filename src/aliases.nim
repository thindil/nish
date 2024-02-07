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

## This module contains code related to the shell's command's aliases, like
## setting them, deleting or executing.

# Standard library imports
import std/[os, paths, parseopt, strutils, tables]
# External modules imports
import contracts, nancy, nimalyzer, termstyle
import norm/[model, sqlite]
# Internal imports
import commandslist, constants, help, input, options, output, resultcode,
    variables, theme, types

const
  aliasesCommands*: seq[string] = @["list", "delete", "show", "add", "edit"]
    ## The list of available subcommands for command alias
  aliasesOptions: Table[char, string] = {'o': "standard output",
      'e': "standard error", 'f': "file", 'q': "quit"}.toTable
    ## The list of available options when setting the output of an alias

using
  db: DbConn # Connection to the shell's database
  aliases: ref AliasesList # The list of aliases available in the selected directory
  arguments: UserInput # The string with arguments entered by the user for the command

proc setAliases*(aliases; directory: Path; db) {.sideEffect, raises: [
    ], tags: [ReadDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect,
        RootEffect],
    contractual.} =
  ## Set the available aliases in the selected directory
  ##
  ## * aliases   - the list of aliases available in the selected directory
  ## * directory - the directory in which the aliases will be set
  ## * db        - the connection to the shell's database
  ##
  ## Returns the parameter aliases with the new list of available aliases
  require:
    directory.len > 0
    db != nil
  body:
    aliases.clear
    var
      dbQuery: string = "SELECT id, name FROM aliases WHERE path='" &
          $directory & "'"
      remainingDirectory: Path = parentDir(path = directory)
    # Construct SQL querry, search for aliases also defined in parent directories
    # if they are recursive
    while remainingDirectory.len > 0:
      dbQuery.add(y = " OR (path='" & $remainingDirectory & "' AND recursive=1)")
      remainingDirectory = parentDir(path = remainingDirectory)
    dbQuery.add(y = " ORDER BY id ASC")
    # Set the aliases
    type LocalAlias = ref object
      id: Positive = 1
      name: string
    var dbAliases: seq[LocalAlias] = @[LocalAlias()]
    try:
      db.rawSelect(qry = dbQuery, objs = dbAliases)
      for dbResult in dbAliases:
        aliases[dbResult.name] = dbResult.id
    except:
      showError(message = "Can't set aliases for the current directory. Reason: ",
          e = getCurrentException(), db = db)

proc listAliases(arguments; aliases; db): ResultCode {.sideEffect, raises: [],
    tags: [ReadIOEffect, WriteIOEffect, ReadDbEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## List available aliases in the current directory, if entered command was
  ## "alias list all" list all declared aliases then.
  ##
  ## * arguments - the user entered text with arguments for showing aliases
  ## * aliases   - the list of aliases available in the current directory
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the list of aliases was shown, otherwise QuitFailure
  require:
    arguments.startsWith(prefix = "list")
    db != nil
  body:
    var table: TerminalTable = TerminalTable()
    try:
      let color: string = getColor(db = db, name = tableHeaders)
      table.add(parts = [style(ss = "ID", style = color), style(ss = "Name",
          style = color), style(ss = "Description", style = color)])
    except:
      return showError(message = "Can't show aliases list. Reason: ",
          e = getCurrentException(), db = db)
    type LocalAlias = ref object
      id: Positive = 1
      name: string
      description: string
    var dbAliases: seq[LocalAlias] = @[LocalAlias()]
    # Show all available aliases declared in the shell
    if arguments == "list all":
      try:
        db.rawSelect(qry = "SELECT id, name, description FROM aliases",
            objs = dbAliases)
      except:
        return showError(message = "Can't read info about alias from database. Reason:",
            e = getCurrentException(), db = db)
      if dbAliases.len == 0:
        showOutput(message = "There are no defined shell's aliases.", db = db)
        return QuitSuccess.ResultCode
    # Show only aliases available in the current directory
    elif arguments[0 .. 3] == "list":
      var index: Natural = 0
      for alias in aliases.values:
        try:
          var dbAlias: LocalAlias = LocalAlias()
          db.rawSelect(qry = "SELECT id, name, description FROM aliases WHERE id=?",
              obj = dbAlias, params = alias)
          if index == 0 and dbAlias.name.len > 0:
            dbAliases = @[]
          dbAliases.add(y = dbAlias)
          index.inc
        except:
          return showError(message = "Can't read info about alias from database. Reason:",
              e = getCurrentException(), db = db)
      if dbAliases[0].name.len == 0:
        showOutput(message = "There are no defined shell's aliases in the current directory.", db = db)
        return QuitSuccess.ResultCode
    try:
      let color: string = getColor(db = db, name = ids)
      for dbResult in dbAliases:
        table.add(parts = [style(ss = dbResult.id, style = color), style(
            ss = dbResult.name, style = color), style(ss = dbResult.description,
            style = getColor(db = db, name = default))])
    except:
      return showError(message = "Can't add an alias to the list. Reason:",
          e = getCurrentException(), db = db)
    try:
      var width: int = 0
      for size in table.getColumnSizes(maxSize = int.high):
        width = width + size + 2
      if arguments == "list all":
        showFormHeader(message = "All available aliases are:",
            width = width.ColumnAmount, db = db)
      else:
        showFormHeader(message = "Available aliases are:",
            width = width.ColumnAmount, db = db)
      table.echoTable
    except:
      return showError(message = "Can't show the list of aliases. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc newAlias*(name: string = ""; path: string = ""; commands: string = "";
    description: string = ""; recursive: bool = true;
    output: string = "output"): Alias {.raises: [], tags: [], contractual.} =
  ## Create a new data structure for the shell's alias.
  ##
  ## * name        - the name of the alias. Must be unique
  ## * path        - the path in which the alias will work
  ## * commands    - the commands to execute by the alias
  ## * description - the description of the alias
  ## * recursive   - if true, the alias should work in children directories
  ##                 of the path too. Default value is true
  ## * output      - where to redirect the output of the alias' commands.
  ##                 Default value is the standard output
  ##
  ## Returns the new data structure for the selected shell's alias.
  ensure:
    result != nil
  body:
    Alias(name: name, path: path, commands: commands, description: description,
        recursive: recursive, output: output)

proc getAliasId(arguments; db): Natural {.sideEffect, raises: [], tags: [
    WriteIOEffect, TimeEffect, ReadDbEffect, ReadIOEffect, RootEffect],
    contractual.} =
  ## Get the ID of the alias. If the user didn't enter the ID, show the list of
  ## aliases and ask the user for ID. Otherwise, check correctness of entered
  ## ID.
  ##
  ## * arguments - the user entered text with arguments for a command
  ## * db        - the connection to the shell's database
  ##
  ## Returns the ID of an alias or 0 if entered ID was invalid or the user
  ## decided to cancel the command.
  require:
    db != nil
    arguments.len > 0
  body:
    result = 0
    var
      alias: Alias = newAlias()
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
      askForName[Alias](db = db, action = actionName & " an alias",
          namesType = "alias", name = alias)
      if alias.description.len == 0:
        return 0
      return alias.id
    result = try:
        parseInt(s = $arguments[argumentsLen - 1 .. ^1])
      except ValueError:
        showError(message = "The Id of the alias must be a positive number.", db = db)
        return 0
    try:
      if not db.exists(T = Alias, cond = "id=?", params = $result):
        showError(message = "The alias with the Id: " & $result &
            " doesn't exists.", db = db)
        return 0
    except:
      showError(message = "Can't find the alias in database. Reason: ",
          e = getCurrentException(), db = db)
      return 0

proc deleteAlias(arguments; aliases; db): ResultCode {.sideEffect, raises: [],
    tags: [WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Delete the selected alias from the shell's database
  ##
  ## * arguments - the user entered text with arguments for the deleting alias
  ## * aliases   - the list of aliases available in the current directory
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the selected alias was properly deleted, otherwise
  ## QuitFailure. Also, updated parameter aliases
  require:
    arguments.startsWith(prefix = "delete")
    db != nil
  body:
    let id: Natural = getAliasId(arguments = arguments, db = db)
    if id == 0:
      return QuitFailure.ResultCode
    try:
      var alias: Alias = newAlias()
      db.select(obj = alias, cond = "id=?", params = $id)
      db.delete(obj = alias)
    except:
      return showError(message = "Can't delete alias from database. Reason: ",
          e = getCurrentException(), db = db)
    try:
      aliases.setAliases(directory = getCurrentDirectory(), db = db)
    except OSError:
      return showError(message = "Can't delete alias, setting a new aliases not work. Reason: ",
          e = getCurrentException(), db = db)
    showOutput(message = "Deleted the alias with Id: " & $id, color = success, db = db)
    return QuitSuccess.ResultCode

proc showAlias(arguments; db): ResultCode {.sideEffect, raises: [], tags: [
    WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect, ReadEnvEffect,
    TimeEffect, RootEffect], contractual.} =
  ## Show details about the selected alias, its ID, name, description and
  ## commands which will be executed
  ##
  ## * arguments - the user entered text with arguments for the showing alias
  ## * db        - the connection to the shell's database
  ##
  ## Returns quitSuccess if the selected alias was properly show, otherwise
  ## QuitFailure.
  require:
    arguments.startsWith(prefix = "show")
    db != nil
  body:
    let id: Natural = getAliasId(arguments = arguments, db = db)
    if id == 0:
      return QuitFailure.ResultCode
    var alias: Alias = newAlias()
    try:
      db.select(obj = alias, cond = "id=?", params = $id)
    except:
      return showError(message = "Can't read alias data from database. Reason: ",
          e = getCurrentException(), db = db)
    var table: TerminalTable = TerminalTable()
    try:
      let
        color: string = getColor(db = db, name = showHeaders)
        color2: string = getColor(db = db, name = default)
      table.add(parts = [style(ss = "Id:", style = color), style(ss = $id,
          style = color2)])
      table.add(parts = [style(ss = "Name:", style = color), style(
          ss = alias.name, style = color2)])
      table.add(parts = [style(ss = "Description:", style = color), style(ss = (
          if alias.description.len > 0: alias.description else: "(none)"),
          style = color2)])
      table.add(parts = [style(ss = "Path:", style = color), style(
          ss = alias.path & (if alias.recursive: " (recursive)" else: ""),
              style = color2)])
      table.add(parts = [style(ss = "Command(s):", style = color), style(
          ss = alias.commands, style = color2)])
      table.add(parts = [style(ss = "Output to:", style = color), style(
          ss = alias.output, style = color2)])
      table.echoTable
    except:
      return showError(message = "Can't show alias. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc addAlias(aliases; db): ResultCode {.sideEffect, raises: [],
    tags: [ReadDbEffect, ReadIOEffect, WriteIOEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Add a new alias to the shell. Ask the user a few questions and fill the
  ## alias values with answers
  ##
  ## * aliases - the list of aliases available in the current directory
  ## * db      - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the new alias was properly set, otherwise QuitFailure.
  ## Also, updated parameter aliases.
  require:
    db != nil
  body:
    let codeColor: string = getColor(db = db, name = helpCode)
    showOutput(message = "You can cancel adding a new alias at any time by double press Escape key or enter word '" &
        style(ss = "exit", style = codeColor) & "' as an answer.", db = db)
    # Set the name for the alias
    showFormHeader(message = "(1/6 or 7) Name", db = db)
    showOutput(message = "The name of the alias. Will be used to execute it. For example: '" &
        style(ss = "ls", style = codeColor) &
        "'. Can't be empty and can contains only letters, numbers and underscores:", db = db)
    showFormPrompt(prompt = "Name", db = db)
    var name: AliasName = ""
    while name.len == 0:
      name = readInput(maxLength = aliasNameLength, db = db)
      if name.len == 0:
        showError(message = "Please enter a name for the alias.", db = db)
      elif not name.validIdentifier:
        name = ""
        showError(message = "Please enter a valid name for the alias.", db = db)
      if name.len == 0:
        showFormPrompt(prompt = "Name", db = db)
    if name == "exit":
      return showError(message = "Adding a new alias cancelled.", db = db)
    # Set the description for the alias
    showFormHeader(message = "(2/6 or 7) Description", db = db)
    showOutput(message = "The description of the alias. It will be show on the list of available aliases and in the alias details. For example: '" &
        style(ss = "List content of the directory.", style = codeColor) &
        "'. Can't contains a new line character. Can be empty.: ", db = db)
    showFormPrompt(prompt = "Description", db = db)
    let description: UserInput = readInput(db = db)
    if description == "exit":
      return showError(message = "Adding a new alias cancelled.", db = db)
    # Set the working directory for the alias
    showFormHeader(message = "(3/6 or 7) Working directory", db = db)
    showOutput(message = "The full path to the directory in which the alias will be available. If you want to have a global alias, set it to '" &
        style(ss = "/", style = codeColor) &
        "'. Can't be empty and must be a path to the existing directory.: ", db = db)
    showFormPrompt(prompt = "Path", db = db)
    var path: Path = "".Path
    while path.len == 0:
      path = ($readInput(db = db)).Path
      if path.len == 0:
        showError(message = "Please enter a path for the alias.", db = db)
      elif not dirExists(dir = $path) and $path != "exit":
        path = "".Path
        showError(message = "Please enter a path to the existing directory", db = db)
      if path.len == 0:
        showFormPrompt(prompt = "Path", db = db)
    if $path == "exit":
      return showError(message = "Adding a new alias cancelled.", db = db)
    # Set the recursiveness for the alias
    showFormHeader(message = "(4/6 or 7) Recursiveness", db = db)
    showOutput(message = "Select if alias is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press '" &
        style(ss = "y", style = codeColor) & "' or '" & style(ss = "n",
        style = codeColor) & "':", db = db)
    let recursive: BooleanInt = if confirm(prompt = "Recursive",
        db = db): 1 else: 0
    # Set the commands to execute for the alias
    showFormHeader(message = "(5/6 or 7) Commands", db = db)
    showOutput(message = "The commands which will be executed when the alias is invoked. If you want to execute more than one command, you can merge them with '" &
        style(ss = "&&", style = codeColor) & "' or '" & style(ss = "||",
        style = codeColor) & "'. For example: '" & style(ss = "clear && ls -a",
        style = codeColor) &
        "'. Commands can't contain a new line character. Can't be empty.:", db = db)
    showFormPrompt(prompt = "Command(s)", db = db)
    var commands: UserInput = ""
    while commands.len == 0:
      commands = readInput(db = db)
      if commands.len == 0:
        showError(message = "Please enter commands for the alias.", db = db)
        showFormPrompt(prompt = "Command(s)", db = db)
    if commands == "exit":
      return showError(message = "Adding a new alias cancelled.", db = db)
    # Set the destination for the alias' output
    showFormHeader(message = "(6/6 or 7) Output", db = db)
    showOutput(message = "Where should be redirected the alias output. If you select the option file, you will be asked for the path to the file. Possible options:", db = db)
    var inputChar: char = selectOption(options = aliasesOptions, default = 's',
        prompt = "Output", db = db)
    var output: UserInput = ""
    case inputChar
    of 'o':
      output = "stdout"
    of 'e':
      output = "stderr"
    of 'f':
      output = "file"
    of 'q':
      output = "exit"
    else:
      discard
    if output == "exit":
      return showError(message = "Adding a new alias cancelled.", db = db)
    elif output == "file":
      # Set the destination for the alias' output
      showFormHeader(message = "(7/7) Output file", db = db)
      showOutput(message = "Enter the path to the file to which output will be append:", db = db)
      showFormPrompt(prompt = "Path", db = db)
      output = ""
      while output.len == 0:
        output = readInput(db = db)
    if output == "exit":
      return showError(message = "Adding a new alias cancelled.", db = db)
    var alias: Alias = newAlias(name = $name, path = $path,
        recursive = recursive == 1, commands = $commands,
        description = $description, output = $output)
    # Check if alias with the same parameters exists in the database
    try:
      if db.exists(T = Alias, cond = "name=?", params = alias.name):
        return showError(message = "There is an alias with the same name in the database.", db = db)
    except:
      return showError(message = "Can't check if the similar alias exists. Reason: ",
          e = getCurrentException(), db = db)
    # Save the alias to the database
    try:
      db.insert(obj = alias)
    except:
      return showError(message = "Can't add the alias to the database. Reason: ",
          e = getCurrentException(), db = db)
    # Refresh the list of available aliases
    try:
      aliases.setAliases(directory = getCurrentDirectory(), db = db)
    except OSError:
      return showError(message = "Can't set aliases for the current directory. Reason: ",
          e = getCurrentException(), db = db)
    showOutput(message = "The new alias '" & name & "' added.",
        color = success, db = db)
    return QuitSuccess.ResultCode

proc editAlias(arguments; aliases; db): ResultCode {.sideEffect, raises: [],
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
    let id: Natural = getAliasId(arguments = arguments, db = db)
    if id == 0:
      return QuitFailure.ResultCode
    var alias: Alias = newAlias()
    try:
      db.select(obj = alias, cond = "id=?", params = $id)
    except:
      return showError(message = "Can't get the alias from database. Reason: ",
          e = getCurrentException(), db = db)
    let
      codeColor: string = getColor(db = db, name = helpCode)
      valueColor: string = getColor(db = db, name = values)
    showOutput(message = "You can cancel editing the alias at any time by double press Escape key or enter word '" &
        style(ss = "exit", style = codeColor) &
        "' as an answer. You can also reuse a current value by leaving an answer empty.", db = db)
    # Set the name for the alias
    showFormHeader(message = "(1/6 or 7) Name", db = db)
    showOutput(message = "The name of the alias. Will be used to execute it. Current value: '" &
        style(ss = alias.name, style = valueColor) &
        "'. Can contains only letters, numbers and underscores.", db = db)
    showFormPrompt(prompt = "Name", db = db)
    var name: AliasName = readInput(maxLength = aliasNameLength, db = db)
    while name.len > 0 and not validIdentifier(s = $name):
      showError(message = "Please enter a valid name for the alias.", db = db)
      name = readInput(maxLength = aliasNameLength, db = db)
    if name == "exit":
      return showError(message = "Editing the alias cancelled.", db = db)
    elif name == "":
      name = alias.name
    # Set the description for the alias
    showFormHeader(message = "(2/6 or 7) Description", db = db)
    showOutput(message = "The description of the alias. It will be show on the list of available aliases and in the alias details. Current value: '" &
        style(ss = alias.description, style = valueColor) &
        "'. Can't contains a new line character.: ", db = db)
    showFormPrompt(prompt = "Description", db = db)
    var description: UserInput = readInput(db = db)
    if description == "exit":
      return showError(message = "Editing the alias cancelled.", db = db)
    elif description == "":
      description = alias.description
    # Set the working directory for the alias
    showFormHeader(message = "(3/6 or 7) Working directory", db = db)
    showOutput(message = "The full path to the directory in which the alias will be available. If you want to have a global alias, set it to '/'. Current value: '" &
        style(ss = alias.path, style = valueColor) &
        "'. Must be a path to the existing directory.", db = db)
    showFormPrompt(prompt = "Path", db = db)
    var path: Path = ($readInput(db = db)).Path
    while path.len > 0 and ($path != "exit" and not dirExists(dir = $path)):
      showError(message = "Please enter a path to the existing directory", db = db)
      path = ($readInput(db = db)).Path
    if $path == "exit":
      return showError(message = "Editing the alias cancelled.", db = db)
    elif $path == "":
      path = alias.path.Path
    # Set the recursiveness for the alias
    showFormHeader(message = "(4/6 or 7) Recursiveness", db = db)
    showOutput(message = "Select if alias is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press 'y' or 'n':", db = db)
    let recursive: BooleanInt = if confirm(prompt = "Recursive",
        db = db): 1 else: 0
    try:
      stdout.writeLine(x = "")
    except IOError:
      discard
    # Set the commands to execute for the alias
    showFormHeader(message = "(5/6 or 7) Commands", db = db)
    showOutput(message = "The commands which will be executed when the alias is invoked. If you want to execute more than one command, you can merge them with '&&' or '||'. Current value: '" &
        style(ss = alias.commands, style = valueColor) &
        "'. Commands can't contain a new line character.:", db = db)
    showFormPrompt(prompt = "Commands", db = db)
    var commands: UserInput = readInput(db = db)
    if commands == "exit":
      return showError(message = "Editing the alias cancelled.", db = db)
    elif commands == "":
      commands = alias.commands
    # Set the destination for the alias' output
    showFormHeader(message = "(6/6 or 7) Output", db = db)
    showOutput(message = "Where should be redirected the alias output. Possible values are stdout (standard output, default), stderr (standard error) or path to the file to which output will be append. Current value: '" &
        style(ss = alias.output, style = valueColor) & "':", db = db)
    var inputChar: char = selectOption(options = aliasesOptions, default = 's',
        prompt = "Output", db = db)
    var output: UserInput = ""
    case inputChar
    of 'o':
      output = "stdout"
    of 'e':
      output = "stderr"
    of 'f':
      output = "file"
    of 'q':
      output = "exit"
    else:
      discard
    if output == "exit":
      return showError(message = "Editing the alias cancelled.", db = db)
    elif output == "file":
      # Set the destination for the alias' output
      showFormHeader(message = "(7/7) Output file", db = db)
      showOutput(message = "Enter the path to the file to which output will be append:", db = db)
      showFormPrompt(prompt = "Path", db = db)
      output = ""
      while output.len == 0:
        output = readInput(db = db)
    if output == "exit":
      return showError(message = "Editing the alias cancelled.", db = db)
    # Save the alias to the database
    try:
      alias.name = $name
      alias.path = $path
      alias.recursive = recursive == 1
      alias.commands = $commands
      alias.description = $description
      alias.output = $output
      db.update(obj = alias)
    except:
      return showError(message = "Can't update the alias. Reason: ",
          e = getCurrentException(), db = db)
    # Refresh the list of available aliases
    try:
      aliases.setAliases(directory = getCurrentDirectory(), db = db)
    except OSError:
      return showError(message = "Can't set aliases for the current directory. Reason: ",
          e = getCurrentException(), db = db)
    showOutput(message = "The alias with Id: '" & $id & "' edited.",
        color = success, db = db)
    return QuitSuccess.ResultCode

proc execAlias*(arguments; aliasId: string; aliases;
    db): ResultCode {.sideEffect, raises: [], tags: [ReadEnvEffect,
    ReadIOEffect, ReadDbEffect, WriteIOEffect, ExecIOEffect, RootEffect],
    contractual.} =
  ## Execute the selected by the user alias. If it is impossible due to lack
  ## of needed arguments or other errors, print information about it.
  ##
  ## * arguments - the user entered text with arguments for executing the alias
  ## * aliasId   - the id of the alias which will be executed
  ## * aliases   - the list of aliases available in the current directory
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the alias was properly executed, otherwise QuitFailure.
  ## Also, updated parameter aliases.
  require:
    aliasId.len > 0
  body:
    result = QuitSuccess.ResultCode
    let
      aliasIndex: string =
        aliasId
      currentDirectory: Path = try:
          getCurrentDirectory()
      except OSError:
        return showError(message = "Can't get current directory. Reason: ",
            e = getCurrentException(), db = db)
    type LocalAlias = ref object
      output: string
      commands: string
    var alias: LocalAlias = LocalAlias()
    try:
      db.rawSelect(qry = "SELECT output, commands FROM aliases WHERE id=?",
          obj = alias, params = aliases[aliasIndex])
    except:
      return showError(message = "Can't get information about the alias from the database. Reason:",
          e = getCurrentException(), db = db)
    var commandArguments: seq[string] = (if arguments.len > 0: initOptParser(
          cmdline = $arguments).remainingArgs else: @[])
    # Add quotes to arguments which contains spaces
    for argument in commandArguments.mitems:
      if " " in argument and argument[0] != '"':
        argument = '"' & argument & '"'
    # Convert all $number in commands to arguments taken from the user
    # input
    var
      argumentPosition: ExtendedNatural = alias.commands.find(sub = '$')
    while argumentPosition > -1 and alias.commands[argumentPosition + 1] in {
        '0' .. '9'}:
      var argumentNumber: Natural = try:
          parseInt(s = alias.commands[argumentPosition + 1] & "")
        except ValueError:
          0
      # Not enough argument entered by the user, quit with error
      if argumentNumber > commandArguments.len:
        return showError(message = "Not enough arguments entered", db = db)
      elif argumentNumber > 0:
        alias.commands = alias.commands.replace(sub = alias.commands[
          argumentPosition..argumentPosition + 1], by = commandArguments[
              argumentNumber - 1])
      else:
        alias.commands = alias.commands.replace(sub = alias.commands[
          argumentPosition..argumentPosition + 1], by = commandArguments.join(sep = " "))
      argumentPosition = alias.commands.find(sub = '$',
          start = argumentPosition + 1)
    # If output location is set to file, create or open the file
    let outputFile: File = try:
          (if alias.output notin ["stdout", "stderr"]: open(
              filename = alias.output, mode = fmWrite) else: nil)
        except IOError:
          return showError(message = "Can't open output file. Reason: ",
              e = getCurrentException(), db = db)
    # Execute the selected alias
    var workingDir: Path = "".Path
    while alias.commands.len > 0:
      var
        conjCommands: bool = false
        userInput: OptParser = initOptParser(cmdline = alias.commands)
      let
        command: UserInput = getArguments(userInput = userInput,
            conjCommands = conjCommands)
      alias.commands = join(a = userInput.remainingArgs, sep = " ")
      try:
        # Threat cd command specially, it should just change the current
        # directory for the alias
        if command[0..2] == "cd ":
          workingDir = getCurrentDirectory()
          setCurrentDir(newDir = $command[3..^1])
          setVariables(newDirectory = getCurrentDirectory(),
              db = db, oldDirectory = workingDir)
          aliases.setAliases(directory = getCurrentDirectory(), db = db)
          continue
        let
          spaceIndex: int = command.find(sub = ' ')
          withShell: bool = getOption(optionName = "execWithShell", db = db,
            defaultValue = "true") == "true"
        result = runCommand(commandName = (if spaceIndex > 0: $(command[0 ..
            spaceIndex]) else: $command), arguments = (if spaceIndex >
            0: command[spaceIndex .. ^1] else: ""),
            withShell = withShell, db = db, output = (if alias.output ==
            "stdout": "" else: alias.output))
        if result != QuitSuccess and conjCommands:
          break
      except:
        showError(message = "Can't execute the command of the alias. Reason: ",
            e = getCurrentException(), db = db)
        break
      if not conjCommands:
        break
    if outputFile != nil:
      outputFile.close
    # Restore old variables and aliases
    if workingDir.len > 0:
      try:
        setVariables(newDirectory = currentDirectory, db = db,
            oldDirectory = getCurrentDirectory())
        setCurrentDir(newDir = $currentDirectory)
        aliases.setAliases(directory = currentDirectory, db = db)
      except OSError:
        return showError(message = "Can't restore aliases and variables. Reason: ",
            e = getCurrentException(), db = db)
    return result

proc initAliases*(db; aliases: ref AliasesList;
    commands: ref CommandsList) {.sideEffect, raises: [], tags: [
    ReadDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect, WriteDbEffect,
    ReadIOEffect, RootEffect], contractual.} =
  ## Initialize the shell's aliases. Set help related to the aliases and
  ## load aliases available in the current directory
  ##
  ## * db          - the connection to the shell's database
  ## * aliases     - the list of aliases available in the current directory
  ## * commands    - the list of the shell's commands
  ##
  ## Returns the updated list of available aliases in the current directory
  ## and the updated list of the shell's commands.
  require:
    db != nil
  body:
    # Add commands related to the shell's aliases
    proc aliasCommand(arguments: UserInput; db;
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
          return showHelpList(command = "alias",
              subcommands = aliasesCommands, db = db)
        # Show the list of available aliases
        if arguments.startsWith(prefix = "list"):
          return listAliases(arguments = arguments, aliases = aliases, db = db)
        # Delete the selected alias
        if arguments.startsWith(prefix = "delete"):
          return deleteAlias(arguments = arguments, aliases = aliases, db = db)
        # Show the selected alias
        if arguments.startsWith(prefix = "show"):
          return showAlias(arguments = arguments, db = db)
        # Add a new alias
        if arguments.startsWith(prefix = "add"):
          return addAlias(aliases = aliases, db = db)
        # Edit the selected alias
        if arguments.startsWith(prefix = "edit"):
          return editAlias(arguments = arguments, aliases = aliases, db = db)
        return showUnknownHelp(subCommand = arguments, command = "alias",
            helpType = "aliases", db = db)

    try:
      addCommand(name = "alias", command = aliasCommand, commands = commands,
          subCommands = aliasesCommands)
    except:
      showError(message = "Can't add commands related to the shell's aliases. Reason: ",
          e = getCurrentException(), db = db)
    # Set the shell's aliases for the current directory
    try:
      aliases.setAliases(directory = getCurrentDirectory(), db = db)
    except OSError:
      showError(message = "Can't initialize aliases. Reason: ",
          e = getCurrentException(), db = db)

proc updateAliasesDb*(db; dbVersion: Natural): ResultCode {.sideEffect,
    raises: [], tags: [WriteDbEffect, ReadDbEffect, WriteIOEffect, RootEffect],
    contractual.} =
  ## Update the table aliases to the new version if needed
  ##
  ## * db        - the connection to the shell's database
  ## * dbVersion - the version of the database schema from which upgrade is make
  ##
  ## Returns QuitSuccess if update was successfull, otherwise QuitFailure and
  ## show message what wrong
  require:
    db != nil
  body:
    try:
      if dbVersion < 3:
        db.exec(query = sql(query = """ALTER TABLE aliases ADD output TEXT NOT NULL"""))
    except DbError:
      return showError(message = "Can't update table for the shell's aliases. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc createAliasesDb*(db): ResultCode {.sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Create the table aliases
  ##
  ## * db - the connection to the shell's database
  ##
  ## Returns QuitSuccess if creation was successfull, otherwise QuitFailure and
  ## show message what wrong
  require:
    db != nil
  body:
    try:
      db.createTables(obj = newAlias())
    except:
      return showError(message = "Can't create 'aliases' table. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

