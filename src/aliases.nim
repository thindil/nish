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

## This module contains code related to the shell's command's aliases, like
## setting them, deleting or executing.

# Standard library imports
import std/[os, osproc, parseopt, strutils, tables, terminal]
# Database library import, depends on version of Nim
when (NimMajor, NimMinor, NimPatch) >= (1, 7, 3):
  import db_connector/db_sqlite
else:
  import std/db_sqlite
# External modules imports
import ansiparse, contracts, nancy, nimalyzer, termstyle
# Internal imports
import commandslist, constants, databaseid, directorypath, help, input, lstring,
    output, resultcode, variables

const aliasesCommands*: array[5, string] = ["list", "delete", "show", "add", "edit"]
  ## The list of available subcommands for command alias

using
  db: DbConn # Connection to the shell's database
  aliases: ref AliasesList # The list of aliases available in the selected directory
  arguments: UserInput # The string with arguments entered by the user for the command

proc setAliases*(aliases; directory: DirectoryPath; db) {.gcsafe, sideEffect,
    raises: [], tags: [ReadDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect,
    RootEffect], contractual.} =
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
    {.warning[ProveInit]: off.}
    aliases.clear
    {.warning[ProveInit]: on.}
    var
      dbQuery: string = "SELECT id, name FROM aliases WHERE path='" &
          directory & "'"
      remainingDirectory: DirectoryPath = parentDir(
          path = $directory).DirectoryPath

    # Construct SQL querry, search for aliases also defined in parent directories
    # if they are recursive
    while remainingDirectory.len > 0:
      dbQuery.add(y = " OR (path='" & remainingDirectory & "' AND recursive=1)")
      remainingDirectory = parentDir(path = $remainingDirectory).DirectoryPath
    dbQuery.add(y = " ORDER BY id ASC")
    # Set the aliases
    try:
      for dbResult in db.fastRows(query = sql(query = dbQuery)):
        let index: LimitedString = try:
            initLimitedString(capacity = maxInputLength, text = dbResult[1])
          except CapacityError:
            showError(message = "Can't set index from " & dbResult[1])
            return
        try:
          aliases[index] = parseInt(s = dbResult[0])
        except ValueError:
          showError(message = "Can't set alias, invalid Id: " &
              dbResult[0])
    except DbError:
      showError(message = "Can't set aliases for the current directory. Reason: ",
          e = getCurrentException())

proc listAliases*(arguments; aliases; db): ResultCode {.sideEffect, raises: [],
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
    arguments.len > 3
    arguments.startsWith(prefix = "list")
    db != nil
  body:
    {.ruleOff: "varDeclared".}
    var table: TerminalTable
    {.ruleOn: "varDeclared".}
    try:
      table.add(parts = [magenta(ss = "ID"), magenta(ss = "Name"), magenta(
          ss = "Description")])
    except UnknownEscapeError, InsufficientInputError, FinalByteError:
      return showError(message = "Can't show aliases list. Reason: ",
          e = getCurrentException())
    # Show all available aliases declared in the shell
    if arguments == "list all":
      try:
        for row in db.fastRows(query = sql(
            query = "SELECT id, name, description FROM aliases")):
          table.add(parts = [row[0], row[1], row[2]])
      except DbError, UnknownEscapeError, InsufficientInputError, FinalByteError:
        return showError(message = "Can't read info about alias from database. Reason:",
            e = getCurrentException())
      showFormHeader(message = "All available aliases are:",
          width = table.getColumnSizes(maxSize = int.high)[0].ColumnAmount, db = db)
    # Show only aliases available in the current directory
    elif arguments[0 .. 3] == "list":
      for alias in aliases.values:
        try:
          let row: Row = db.getRow(query = sql(
              query = "SELECT id, name, description FROM aliases WHERE id=?"),
            args = alias)
          table.add(parts = [row[0], row[1], row[2]])
        except DbError, UnknownEscapeError, InsufficientInputError, FinalByteError:
          return showError(message = "Can't read info about alias from database. Reason:",
              e = getCurrentException())
      showFormHeader(message = "Available aliases are:",
          width = table.getColumnSizes(maxSize = int.high)[0].ColumnAmount, db = db)
    try:
      table.echoTable
    except IOError, Exception:
      return showError(message = "Can't show the list of aliases. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc deleteAlias*(arguments; aliases; db): ResultCode {.gcsafe, sideEffect,
    raises: [], tags: [WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Delete the selected alias from the shell's database
  ##
  ## * arguments - the user entered text with arguments for the deleting alias
  ## * aliases   - the list of aliases available in the current directory
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the selected alias was properly deleted, otherwise
  ## QuitFailure. Also, updated paramete aliases
  require:
    arguments.len > 5
    arguments.startsWith(prefix = "delete")
    db != nil
  body:
    if arguments.len < 8:
      return showError(message = "Enter the Id of the alias to delete.")
    let id: DatabaseId = try:
        parseInt(s = $arguments[7 .. ^1]).DatabaseId
      except ValueError:
        return showError(message = "The Id of the alias must be a positive number.")
    try:
      if db.execAffectedRows(query = sql(
          query = "DELETE FROM aliases WHERE id=?"), args = id.int) == 0:
        return showError(message = "The alias with the Id: " & $id &
          " doesn't exists.")
    except DbError:
      return showError(message = "Can't delete alias from database. Reason: ",
          e = getCurrentException())
    try:
      aliases.setAliases(directory = getCurrentDirectory().DirectoryPath, db = db)
    except OSError:
      return showError(message = "Can't delete alias, setting a new aliases not work. Reason: ",
          e = getCurrentException())
    showOutput(message = "Deleted the alias with Id: " & $id, fgColor = fgGreen)
    return QuitSuccess.ResultCode

proc showAlias*(arguments; aliases; db): ResultCode {.sideEffect, raises: [],
    tags: [WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Show details about the selected alias, its ID, name, description and
  ## commands which will be executed
  ##
  ## * arguments - the user entered text with arguments for the showing alias
  ## * aliases   - the list of aliases available in the current directory
  ## * db        - the connection to the shell's database
  ##
  ## Returns quitSuccess if the selected alias was properly show, otherwise
  ## QuitFailure.
  require:
    arguments.len > 3
    arguments.startsWith(prefix = "show")
    db != nil
  body:
    if arguments.len < 6:
      return showError(message = "Enter the ID of the alias to show.")
    let id: DatabaseId = try:
        parseInt(s = $arguments[5 .. ^1]).DatabaseId
      except ValueError:
        return showError(message = "The Id of the alias must be a positive number.")
    let row: Row = try:
          db.getRow(query = sql(query = "SELECT name, commands, description, path, recursive, output FROM aliases WHERE id=?"), args = id)
      except DbError:
        return showError(message = "Can't read alias data from database. Reason: ",
            e = getCurrentException())
    if row[0] == "":
      return showError(message = "The alias with the ID: " & $id &
        " doesn't exists.")
    {.ruleOff: "varDeclared".}
    var table: TerminalTable
    {.ruleOn: "varDeclared".}
    try:
      table.add(parts = [magenta(ss = "Id:"), $id])
      table.add(parts = [magenta(ss = "Name:"), row[0]])
      table.add(parts = [magenta(ss = "Description:"), (if row[2].len > 0: row[
          2] else: "(none)")])
      table.add(parts = [magenta(ss = "Path:"), row[3] & (if row[4] ==
          "1": " (recursive)" else: "")])
      table.add(parts = [magenta(ss = "Command(s):"), row[1]])
      table.add(parts = [magenta(ss = "Output to:"), row[5]])
    except UnknownEscapeError, InsufficientInputError, FinalByteError:
      return showError(message = "Can't show alias. Reason: ",
          e = getCurrentException())
    try:
      table.echoTable
    except IOError, Exception:
      return showError(message = "Can't show alias. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc addAlias*(aliases; db): ResultCode {.sideEffect, raises: [],
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
    showOutput(message = "You can cancel adding a new alias at any time by double press Escape key or enter word 'exit' as an answer.")
    # Set the name for the alias
    showFormHeader(message = "(1/6) Name", db = db)
    showOutput(message = "The name of the alias. Will be used to execute it. For example: 'ls'. Can't be empty and can contains only letters, numbers and underscores:")
    showOutput(message = "Name: ", newLine = false)
    var name: AliasName = emptyLimitedString(capacity = aliasNameLength)
    while name.len == 0:
      name = readInput(maxLength = aliasNameLength)
      if name.len == 0:
        showError(message = "Please enter a name for the alias.")
      elif not validIdentifier(s = $name):
        try:
          name.text = ""
          showError(message = "Please enter a valid name for the alias.")
        except CapacityError:
          showError(message = "Can't set empty name for alias.")
      if name.len == 0:
        showOutput(message = "Name: ", newLine = false)
    if name == "exit":
      return showError(message = "Adding a new alias cancelled.")
    # Set the description for the alias
    showFormHeader(message = "(2/6) Description", db = db)
    showOutput(message = "The description of the alias. It will be show on the list of available aliases and in the alias details. For example: 'List content of the directory.'. Can't contains a new line character. Can be empty.: ")
    showOutput(message = "Description: ", newLine = false)
    let description: UserInput = readInput()
    if description == "exit":
      return showError(message = "Adding a new alias cancelled.")
    # Set the working directory for the alias
    showFormHeader(message = "(3/6) Working directory", db = db)
    showOutput(message = "The full path to the directory in which the alias will be available. If you want to have a global alias, set it to '/'. Can't be empty and must be a path to the existing directory.: ")
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
      return showError(message = "Adding a new alias cancelled.")
    # Set the recursiveness for the alias
    showFormHeader(message = "(4/6) Recursiveness", db = db)
    showOutput(message = "Select if alias is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press 'y' or 'n':")
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
    showOutput(message = $inputChar)
    let recursive: BooleanInt = if inputChar in {'n', 'N'}: 0 else: 1
    # Set the commands to execute for the alias
    showFormHeader(message = "(5/6) Commands", db = db)
    showOutput(message = "The commands which will be executed when the alias is invoked. If you want to execute more than one command, you can merge them with '&&' or '||'. For example: 'clear && ls -a'. Commands can't contain a new line character. Can't be empty.:")
    showOutput(message = "Command(s): ", newLine = false)
    var commands: UserInput = emptyLimitedString(capacity = maxInputLength)
    while commands.len == 0:
      commands = readInput()
      if commands.len == 0:
        showError(message = "Please enter commands for the alias.")
        showOutput(message = "Command(s): ", newLine = false)
    if commands == "exit":
      return showError(message = "Adding a new alias cancelled.")
    # Set the destination for the alias' output
    showFormHeader(message = "(6/6) Output", db = db)
    showOutput(message = "Where should be redirected the alias output. Possible values are stdout (standard output, default), stderr (standard error) or path to the file to which output will be append. For example: 'output.txt'.:")
    showOutput(message = "Output to: ", newLine = false)
    var output: UserInput = readInput()
    if output == "exit":
      return showError(message = "Adding a new alias cancelled.")
    elif output == "":
      try:
        output.text = "stdout"
      except CapacityError:
        return showError(message = "Adding a new alias cancelled. Reason: Can't set output for the alias")
    # Check if alias with the same parameters exists in the database
    try:
      if db.getValue(query = sql(query = "SELECT id FROM aliases WHERE name=? AND path=? AND recursive=? AND commands=?"),
          args = [$name, $path, $recursive, $commands]).len > 0:
        return showError(message = "There is an alias with the same name, path and commands in the database.")
    except DbError:
      return showError(message = "Can't check if the similar alias exists. Reason: ",
          e = getCurrentException())
    # Save the alias to the database
    try:
      if db.tryInsertID(query = sql(query = "INSERT INTO aliases (name, path, recursive, commands, description, output) VALUES (?, ?, ?, ?, ?, ?)"),
          args = [$name, $path, $recursive, $commands, $description,
          $output]) == -1:
        return showError(message = "Can't add alias.")
    except DbError:
      return showError(message = "Can't add the alias to the database. Reason: ",
          e = getCurrentException())
    # Refresh the list of available aliases
    try:
      aliases.setAliases(directory = getCurrentDirectory().DirectoryPath, db = db)
    except OSError:
      return showError(message = "Can't set aliases for the current directory. Reason: ",
          e = getCurrentException())
    showOutput(message = "The new alias '" & name & "' added.",
        fgColor = fgGreen)
    return QuitSuccess.ResultCode

proc editAlias*(arguments; aliases; db): ResultCode {.sideEffect,
    raises: [], tags: [ReadDbEffect, ReadIOEffect, WriteIOEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Edit the selected alias
  ##
  ## * arguments - the user entered text with arguments for the editing alias
  ## * aliases   - the list of aliases available in the current directory
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the alias was properly edited, otherwise QuitFailure.
  ## Also, updated parameter aliases.
  require:
    arguments.len > 3
    db != nil
  body:
    if arguments.len < 6:
      return showError(message = "Enter the ID of the alias to edit.")
    let id: DatabaseId = try:
        parseInt(s = $arguments[5 .. ^1]).DatabaseId
      except ValueError:
        return showError(message = "The Id of the alias must be a positive number.")
    let row: Row = try:
          db.getRow(query = sql(query = "SELECT name, path, commands, description, output FROM aliases WHERE id=?"), args = id)
      except DbError:
        return showError(message = "The alias with the ID: " & $id & " doesn't exists.")
    showOutput(message = "You can cancel editing the alias at any time by double press Escape key or enter word 'exit' as an answer. You can also reuse a current value by leaving an answer empty.")
    # Set the name for the alias
    showFormHeader(message = "(1/6) Name", db = db)
    showOutput(message = "The name of the alias. Will be used to execute it. Current value: '",
        newLine = false)
    showOutput(message = row[0], newLine = false, fgColor = fgMagenta)
    showOutput(message = "'. Can contains only letters, numbers and underscores.")
    showOutput(message = "Name: ", newLine = false)
    var name: AliasName = readInput(maxLength = aliasNameLength)
    while name.len > 0 and not validIdentifier(s = $name):
      showError(message = "Please enter a valid name for the alias.")
      name = readInput(maxLength = aliasNameLength)
    if name == "exit":
      return showError(message = "Editing the alias cancelled.")
    elif name == "":
      try:
        name.text = row[0]
      except CapacityError:
        return showError(message = "Editing the alias cancelled. Reason: Can't set name for the alias")
    # Set the description for the alias
    showFormHeader(message = "(2/6) Description", db = db)
    showOutput(message = "The description of the alias. It will be show on the list of available aliases and in the alias details. Current value: '",
        newLine = false)
    showOutput(message = row[3], newLine = false, fgColor = fgMagenta)
    showOutput(message = "'. Can't contains a new line character.: ")
    showOutput(message = "Description: ", newLine = false)
    var description: UserInput = readInput()
    if description == "exit":
      return showError(message = "Editing the alias cancelled.")
    elif description == "":
      try:
        description.text = row[3]
      except CapacityError:
        return showError(message = "Editing the alias cancelled. Reason: Can't set description for the alias")
    # Set the working directory for the alias
    showFormHeader(message = "(3/6) Working directory", db = db)
    showOutput(message = "The full path to the directory in which the alias will be available. If you want to have a global alias, set it to '/'. Current value: '",
        newLine = false)
    showOutput(message = row[1], newLine = false, fgColor = fgMagenta)
    showOutput(message = "'. Must be a path to the existing directory.")
    var path: DirectoryPath = ($readInput()).DirectoryPath
    while path.len > 0 and (path != "exit" and not dirExists(dir = $path)):
      showError(message = "Please enter a path to the existing directory")
      path = ($readInput()).DirectoryPath
    if path == "exit":
      return showError(message = "Editing the alias cancelled.")
    elif path == "":
      path = row[1].DirectoryPath
    # Set the recursiveness for the alias
    showFormHeader(message = "(4/6) Recursiveness", db = db)
    showOutput(message = "Select if alias is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press 'y' or 'n':")
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
    showOutput(message = "")
    # Set the commands to execute for the alias
    showFormHeader(message = "(5/6) Commands", db = db)
    showOutput(message = "The commands which will be executed when the alias is invoked. If you want to execute more than one command, you can merge them with '&&' or '||'. Current value: '",
        newLine = false)
    showOutput(message = row[2], newLine = false, fgColor = fgMagenta)
    showOutput(message = "'. Commands can't contain a new line character.:")
    showOutput(message = "Commands: ", newLine = false)
    var commands: UserInput = readInput()
    if commands == "exit":
      return showError(message = "Editing the alias cancelled.")
    elif commands == "":
      try:
        commands.text = row[2]
      except CapacityError:
        return showError(message = "Editing the alias cancelled. Reason: Can't set commands for the alias")
    # Set the destination for the alias' output
    showFormHeader(message = "(6/6) Output", db = db)
    showOutput(message = "Where should be redirected the alias output. Possible values are stdout (standard output, default), stderr (standard error) or path to the file to which output will be append. Current value: '",
        newLine = false)
    showOutput(message = row[4], newLine = false, fgColor = fgMagenta)
    showOutput(message = "':")
    showOutput(message = "Output to: ", newLine = false)
    var output: UserInput = readInput()
    if output == "exit":
      return showError(message = "Editing the alias cancelled.")
    elif output == "":
      try:
        output.text = row[4]
      except CapacityError:
        return showError(message = "Editing the alias cancelled. Reason: Can't set output for the alias")
    # Save the alias to the database
    try:
      if db.execAffectedRows(query = sql(
          query = "UPDATE aliases SET name=?, path=?, recursive=?, commands=?, description=?, output=? where id=?"),
           args = [$name, $path, $recursive, $commands, $description, $output,
               $id]) != 1:
        return showError(message = "Can't edit the alias.")
    except DbError:
      return showError(message = "Can't save the alias to database. Reason: ",
          e = getCurrentException())
    # Refresh the list of available aliases
    try:
      aliases.setAliases(directory = getCurrentDirectory().DirectoryPath, db = db)
    except OSError:
      return showError(message = "Can't set aliases for the current directory. Reason: ",
          e = getCurrentException())
    showOutput(message = "The alias  with Id: '" & $id & "' edited.",
        fgColor = fgGreen)
    return QuitSuccess.ResultCode

proc execAlias*(arguments; aliasId: string; aliases; db): ResultCode {.gcsafe,
    sideEffect, raises: [], tags: [ReadEnvEffect, ReadIOEffect, ReadDbEffect,
    WriteIOEffect, ExecIOEffect, RootEffect], contractual.} =
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
      aliasIndex: LimitedString = try:
          initLimitedString(capacity = maxInputLength, text = aliasId)
        except CapacityError:
          return showError(message = "Can't set alias index for " & aliasId)
      outputLocation: string = try:
        db.getValue(query = sql(query = "SELECT output FROM aliases WHERE id=?"),
            args = aliases[aliasIndex])
      except KeyError, DbError:
        return showError(message = "Can't get output for alias. Reason: ",
            e = getCurrentException())
      currentDirectory: DirectoryPath = try:
          getCurrentDirectory().DirectoryPath
      except OSError:
        return showError(message = "Can't get current directory. Reason: ",
            e = getCurrentException())
    var
      inputString: string = try:
          db.getValue(query = sql(query = "SELECT commands FROM aliases WHERE id=?"),
              args = aliases[aliasIndex])
        except KeyError, DbError:
          return showError(message = "Can't get commands for alias. Reason: ",
              e = getCurrentException())
      commandArguments: seq[string] = (if arguments.len > 0: initOptParser(
          cmdline = $arguments).remainingArgs else: @[])
    # Add quotes to arguments which contains spaces
    for argument in commandArguments.mitems:
      if " " in argument and argument[0] != '"':
        argument = '"' & argument & '"'
    # Convert all $number in commands to arguments taken from the user
    # input
    var
      argumentPosition: ExtendedNatural = inputString.find(sub = '$')
    while argumentPosition > -1:
      var argumentNumber: Natural = try:
          parseInt(s = inputString[argumentPosition + 1] & "")
        except ValueError:
          0
      # Not enough argument entered by the user, quit with error
      if argumentNumber > commandArguments.len:
        return showError(message = "Not enough arguments entered")
      elif argumentNumber > 0:
        inputString = inputString.replace(sub = inputString[
          argumentPosition..argumentPosition + 1], by = commandArguments[
              argumentNumber - 1])
      else:
        inputString = inputString.replace(sub = inputString[
          argumentPosition..argumentPosition + 1], by = commandArguments.join(sep = " "))
      argumentPosition = inputString.find(sub = '$', start = argumentPosition + 1)
    # If output location is set to file, create or open the file
    let outputFile: File = try:
          (if outputLocation notin ["stdout", "stderr"]: open(
              filename = outputLocation, mode = fmWrite) else: nil)
        except IOError:
          return showError(message = "Can't open output file. Reason: ",
              e = getCurrentException())
    # Execute the selected alias
    var workingDir: string = ""
    while inputString.len > 0:
      var
        conjCommands: bool = false
        userInput: OptParser = initOptParser(cmdline = inputString)
        returnCode: int = QuitSuccess
        resultOutput: string = ""
      let
        command: UserInput = getArguments(userInput = userInput,
            conjCommands = conjCommands)
      inputString = join(a = userInput.remainingArgs, sep = " ")
      try:
        # Threat cd command specially, it should just change the current
        # directory for the alias
        if command[0..2] == "cd ":
          workingDir = getCurrentDirectory()
          setCurrentDir(newDir = $command[3..^1])
          setVariables(newDirectory = getCurrentDirectory().DirectoryPath, db = db,
              oldDirectory = workingDir.DirectoryPath)
          aliases.setAliases(directory = getCurrentDirectory().DirectoryPath, db = db)
          continue
        if outputLocation == "stdout":
          returnCode = execCmd(command = $command)
        else:
          (resultOutput, returnCode) = execCmdEx(command = $command)
          if outputFile != nil:
            outputFile.write(s = resultOutput)
          else:
            showError(message = resultOutput)
        result = returnCode.ResultCode
        if result != QuitSuccess and conjCommands:
          break
      except OSError, IOError, Exception:
        showError(message = "Can't execute the command of the alias. Reason: ",
            e = getCurrentException())
        break
      if not conjCommands:
        break
    if outputFile != nil:
      outputFile.close
    # Restore old variables and aliases
    if workingDir.len > 0:
      try:
        setVariables(newDirectory = currentDirectory, db = db,
            oldDirectory = getCurrentDirectory().DirectoryPath)
        setCurrentDir(newDir = $currentDirectory)
        aliases.setAliases(directory = currentDirectory, db = db)
      except OSError:
        return showError(message = "Can't restore aliases and variables. Reason: ",
            e = getCurrentException())
    return result

proc initAliases*(db; aliases: ref AliasesList;
    commands: ref CommandsList) {.sideEffect, raises: [], tags: [
    ReadDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect, WriteDbEffect,
    ReadIOEffect, RootEffect], contractual.} =
  ## Initialize the shell's aliases. Set help related to the aliases and
  ## load aliases available in the current directory
  ##
  ## * helpContent - the HelpTable with help content of the shell
  ## * db          - the connection to the shell's database
  ## * aliases     - the list of aliases available in the current directory
  ## * commands    - the list of the shell's commands
  ##
  ## Returns the updated list of available aliases in the current directory,
  ## the updated helpContent with the help for the commands related to the
  ## shell's aliases and the updated list of the shell's commands.
  require:
    db != nil
  body:
    # Add commands related to the shell's aliases
    proc aliasCommand(arguments: UserInput; db: DbConn;
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
        {.ruleOff: "ifStatements".}
        # No subcommand entered, show available options
        if arguments.len == 0:
          return showHelpList(command = "alias",
              subcommands = aliasesCommands)
        # Show the list of available aliases
        elif arguments.startsWith(prefix = "list"):
          return listAliases(arguments = arguments, aliases = aliases, db = db)
        # Delete the selected alias
        elif arguments.startsWith(prefix = "delete"):
          return deleteAlias(arguments = arguments, aliases = aliases, db = db)
        # Show the selected alias
        elif arguments.startsWith(prefix = "show"):
          return showAlias(arguments = arguments, aliases = aliases, db = db)
        # Add a new alias
        elif arguments.startsWith(prefix = "add"):
          return addAlias(aliases = aliases, db = db)
        # Edit the selected alias
        elif arguments.startsWith(prefix = "edit"):
          return editAlias(arguments = arguments, aliases = aliases, db = db)
        {.ruleOn: "ifStatements".}
        try:
          return showUnknownHelp(subCommand = arguments,
              command = initLimitedString(capacity = 5, text = "alias"),
                  helpType = initLimitedString(capacity = 7,
                      text = "aliases"))
        except CapacityError:
          return QuitFailure.ResultCode

    try:
      addCommand(name = initLimitedString(capacity = 5, text = "alias"),
          command = aliasCommand, commands = commands)
    except CapacityError, CommandsListError:
      showError(message = "Can't add commands related to the shell's aliases. Reason: ",
          e = getCurrentException())
    # Set the shell's aliases for the current directory
    try:
      aliases.setAliases(directory = getCurrentDirectory().DirectoryPath, db = db)
    except OSError:
      showError(message = "Can't initialize aliases. Reason: ",
          e = getCurrentException())

proc updateAliasesDb*(db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Update the table aliases to the new version if needed
  ##
  ## * db - the connection to the shell's database
  ##
  ## Returns QuitSuccess if update was successfull, otherwise QuitFailure and
  ## show message what wrong
  require:
    db != nil
  body:
    try:
      db.exec(query = sql(query = """ALTER TABLE aliases ADD output VARCHAR(""" & $maxInputLength &
                  """) NOT NULL DEFAULT 'stdout'"""))
    except DbError:
      return showError(message = "Can't update table for the shell's aliases. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc createAliasesDb*(db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
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
      db.exec(query = sql(query = """CREATE TABLE aliases (
                   id          INTEGER       PRIMARY KEY,
                   name        VARCHAR(""" & $aliasNameLength &
              """) NOT NULL,
                   path        VARCHAR(""" & $maxInputLength &
              """) NOT NULL,
                   recursive   BOOLEAN       NOT NULL,
                   commands    VARCHAR(""" & $maxInputLength &
              """) NOT NULL,
                   description VARCHAR(""" & $maxInputLength &
              """) NOT NULL,
                   output VARCHAR(""" & $maxInputLength &
              """) NOT NULL DEFAULT 'stdout')"""))
    except DbError, CapacityError:
      return showError(message = "Can't create 'aliases' table. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

