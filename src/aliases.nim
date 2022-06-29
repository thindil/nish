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

import std/[db_sqlite, os, osproc, parseopt, strutils, tables, terminal]
import columnamount, constants, databaseid, directorypath, history, input,
    lstring, output, resultcode

type
  AliasName* = LimitedString
    ## FUNCTION
    ##
    ## Used to store aliases names in tables and database.
  AliasesList* = OrderedTable[AliasName, int]
    ## FUNCTION
    ##
    ## Used to store the available aliases in the selected directory

using
  db: DbConn # Connection to the shell's database
  aliases: var AliasesList # The list of aliases available in the selected directory
  arguments: UserInput # The string with arguments entered by the user for the command
  historyIndex: var HistoryRange # The index of the last command in the shell's history

proc setAliases*(aliases; directory: DirectoryPath; db) {.gcsafe, sideEffect, raises: [], tags: [ReadDbEffect,
        WriteIOEffect, ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Set the available aliases in the selected directory
  ##
  ## PARAMETERS
  ##
  ## * aliases   - the list of aliases available in the selected directory
  ## * directory - the directory in which the aliases will be set
  ## * db        - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## The parameter aliases with the new list of available aliases
  aliases = initOrderedTable[AliasName, int]()
  var
    dbQuery: string = "SELECT id, name FROM aliases WHERE path='" & directory & "'"
    remainingDirectory: DirectoryPath = parentDir(
        path = $directory).DirectoryPath

  # Construct SQL querry, search for aliases also defined in parent directories
  # if they are recursive
  while remainingDirectory != "":
    dbQuery.add(y = " OR (path='" & remainingDirectory & "' AND recursive=1)")
    remainingDirectory = parentDir(path = $remainingDirectory).DirectoryPath
  dbQuery.add(y = " ORDER BY id ASC")
  # Set the aliases
  try:
    for dbResult in db.fastRows(query = sql(query = dbQuery)):
      let index = try:
          initLimitedString(capacity = maxInputLength, text = dbResult[1])
        except CapacityError:
          discard showError(message = "Can't set index from " & dbResult[1])
          return
      try:
        aliases[index] = parseInt(s = dbResult[0])
      except ValueError:
        discard showError(message = "Can't set alias, invalid Id: " & dbResult[0])
  except DbError:
    discard showError(message = "Can't set aliases for the current directory. Reason: ",
        e = getCurrentException())

proc listAliases*(arguments; historyIndex; aliases: AliasesList;
    db) {.gcsafe, sideEffect, raises: [], tags: [ReadIOEffect, WriteIOEffect,
        ReadDbEffect, WriteDbEffect, ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## List available aliases in the current directory, if entered command was
  ## "alias list all" list all declared aliases then.
  ##
  ## PARAMETERS
  ##
  ## * arguments    - the user entered text with arguments for showing aliases
  ## * historyIndex - the index of command in the shell's history
  ## * aliases      - the list of aliases available in the current directory
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## The parameter historyIndex updated after execution of showing the aliases'
  ## list
  let
    columnLength: ColumnAmount = try: db.getValue(query =
        sql(query = "SELECT name FROM aliases ORDER BY LENGTH(name) DESC LIMIT 1")).len().ColumnAmount except DbError: 10.ColumnAmount
    spacesAmount: ColumnAmount = try: terminalWidth().ColumnAmount /
        12 except ValueError: 6.ColumnAmount
  if arguments == "list":
    showFormHeader(message = "Available aliases are:")
    try:
      showOutput(message = indent(s = "ID   $1 Output Description" % [alignLeft(
        s = "Name",
        count = columnLength.int)], count = spacesAmount.int),
            fgColor = fgMagenta)
    except ValueError:
      showOutput(message = indent(s = "ID   Name Output Description",
          count = spacesAmount.int), fgColor = fgMagenta)
    for alias in aliases.values:
      try:
        let row: Row = db.getRow(query = sql(
            query = "SELECT id, name, output, description FROM aliases WHERE id=?"),
          args = alias)
        showOutput(message = indent(s = alignLeft(row[0], count = 4) & " " &
            alignLeft(s = row[1], count = columnLength.int) & " " & row[2] &
                " " & row[3], count = spacesAmount.int))
      except DbError:
        discard showError(message = "Can't read info about alias from database. Reason:",
            e = getCurrentException())
        return
    historyIndex = updateHistory(commandToAdd = "alias list", db = db)
  elif arguments == "list all":
    showFormHeader(message = "All available aliases are:")
    try:
      showOutput(message = indent(s = "ID   $1 Output Description" % [alignLeft(
          s = "Name", count = columnLength.int)], count = spacesAmount.int),
              fgColor = fgMagenta)
    except ValueError:
      showOutput(message = indent(s = "ID   Name Output Description",
          count = spacesAmount.int), fgColor = fgMagenta)
    try:
      for row in db.fastRows(query = sql(
          query = "SELECT id, name, output, description FROM aliases")):
        showOutput(message = indent(s = alignLeft(row[0], count = 4) & " " &
            alignLeft(s = row[1], count = columnLength.int) & " " & row[2] &
                " " & row[3], count = spacesAmount.int))
    except DbError:
      discard showError(message = "Can't read info about alias from database. Reason:",
          e = getCurrentException())
      return
    historyIndex = updateHistory(commandToAdd = "alias list all", db = db)

proc deleteAlias*(arguments; historyIndex; aliases; db): ResultCode {.gcsafe,
        sideEffect, raises: [], tags: [
        WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect, ReadEnvEffect,
            TimeEffect].} =
  ## FUNCTION
  ##
  ## Delete the selected alias from the shell's database
  ##
  ## PARAMETERS
  ##
  ## * arguments    - the user entered text with arguments for the deleting
  ##                  alias
  ## * historyIndex - the index of the last command in the shell's history
  ## * aliases      - the list of aliases available in the current directory
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the selected alias was properly deleted, otherwise
  ## QuitFailure. Also, updated parameters historyIndex and aliases
  if arguments.len() < 8:
    historyIndex = updateHistory(commandToAdd = "alias delete", db = db,
        returnCode = QuitFailure.ResultCode)
    return showError(message = "Enter the Id of the alias to delete.")
  let id: DatabaseId = try:
      parseInt(s = $arguments[7 .. ^1]).DatabaseId
    except ValueError:
      return showError(message = "The Id of the alias must be a positive number.")
  try:
    if db.execAffectedRows(query = sql(query = "DELETE FROM aliases WHERE id=?"),
        id.int) == 0:
      historyIndex = updateHistory(commandToAdd = "alias delete", db = db,
          returnCode = QuitFailure.ResultCode)
      return showError(message = "The alias with the Id: " & $id &
        " doesn't exists.")
  except DbError:
    return showError(message = "Can't delete alias from database. Reason: ",
        e = getCurrentException())
  historyIndex = updateHistory(commandToAdd = "alias delete", db = db)
  try:
    aliases.setAliases(directory = getCurrentDir().DirectoryPath, db = db)
  except OSError:
    return showError(message = "Can't delete alias, setting a new aliases not work. Reason: ",
        e = getCurrentException())
  showOutput(message = "Deleted the alias with Id: " & $id, fgColor = fgGreen)
  return QuitSuccess.ResultCode

proc showAlias*(arguments; historyIndex; aliases: AliasesList;
    db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect, ReadEnvEffect,
    TimeEffect].} =
  ## FUNCTION
  ##
  ## Show details about the selected alias, its ID, name, description and
  ## commands which will be executed
  ##
  ## PARAMETERS
  ##
  ## * arguments    - the user entered text with arguments for the showing
  ##                  alias
  ## * historyIndex - the index of the last command in the shell's history
  ## * aliases      - the list of aliases available in the current directory
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the selected alias was properly show, otherwise
  ## QuitFailure. Also, updated parameter historyIndex
  if arguments.len() < 6:
    historyIndex = updateHistory(commandToAdd = "alias show", db = db,
        returnCode = QuitFailure.ResultCode)
    return showError(message = "Enter the ID of the alias to show.")
  let id: DatabaseId = try:
      parseInt(s = $arguments[5 .. ^1]).DatabaseId
    except ValueError:
      return showError(message = "The Id of the alias must be a positive number.")
  let row: Row = try:
        db.getRow(query = sql(query = "SELECT name, commands, description, path, recursive FROM aliases WHERE id=?"), args = id)
    except DbError:
      return showError(message = "Can't read alias data from database. Reason: ",
          e = getCurrentException())
  if row[0] == "":
    historyIndex = updateHistory(commandToAdd = "alias show", db = db,
        returnCode = QuitFailure.ResultCode)
    return showError(message = "The alias with the ID: " & $id &
      " doesn't exists.")
  historyIndex = updateHistory(commandToAdd = "alias show", db = db)
  let spacesAmount: ColumnAmount = try:
      terminalWidth().ColumnAmount / 12
    except ValueError:
      6.ColumnAmount
  showOutput(message = indent(s = alignLeft(s = "Id:", count = 13),
      count = spacesAmount.int), newLine = false, fgColor = fgMagenta)
  showOutput(message = $id)
  showOutput(message = indent(s = alignLeft(s = "Name:", count = 13),
      count = spacesAmount.int), newLine = false, fgColor = fgMagenta)
  showOutput(message = row[0])
  showOutput(message = indent(s = "Description: ", count = spacesAmount.int),
      newLine = false, fgColor = fgMagenta)
  showOutput(message = row[2])
  if row[4] == "1":
    showOutput(message = indent(s = alignLeft(s = "Path:", count = 13),
        count = spacesAmount.int), newLine = false, fgColor = fgMagenta)
    showOutput(message = row[3] & " (recursive)")
  else:
    showOutput(message = indent(s = alignLeft(s = "Path:", count = 13),
        count = spacesAmount.int), newLine = false, fgColor = fgMagenta)
    showOutput(message = row[3])
  showOutput(message = indent(s = alignLeft(s = "Command(s):", count = 13),
      count = spacesAmount.int), newLine = false, fgColor = fgMagenta)
  showOutput(message = row[1])
  return QuitSuccess.ResultCode

proc helpAliases*(db): HistoryRange {.gcsafe, sideEffect, raises: [], tags: [
    ReadDbEffect, WriteDbEffect, ReadIOEffect, WriteIOEffect, ReadEnvEffect,
    TimeEffect].} =
  ## FUNCTION
  ##
  ## Show short help about available subcommands related to the aliases
  ##
  ## PARAMETERS
  ##
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## The new length of the shell's commands' history.
  showOutput(message = """Available subcommands are: list, delete, show, add, edit

        To see more information about the subcommand, type help alias [command],
        for example: help alias list.
""")
  return updateHistory(commandToAdd = "alias", db = db)

proc addAlias*(historyIndex; aliases; db): ResultCode {.gcsafe, sideEffect,
    raises: [], tags: [ReadDbEffect, ReadIOEffect, WriteIOEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Add a new alias to the shell. Ask the user a few questions and fill the
  ## alias values with answers
  ##
  ## PARAMETERS
  ##
  ## * historyIndex - the index of the last command in the shell's history
  ## * aliases      - the list of aliases available in the current directory
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the new alias was properly set, otherwise QuitFailure.
  ## Also, updated parameter historyIndex and aliases.
  showOutput(message = "You can cancel adding a new alias at any time by double press Escape key.")
  showFormHeader(message = "(1/6) Name")
  showOutput(message = "The name of the alias. Will be used to execute it. For example: 'ls'. Can't be empty and can contains only letters, numbers and underscores:")
  showOutput(message = "Name: ", newLine = false)
  var name: AliasName = emptyLimitedString(capacity = aliasNameLength)
  while name.len() == 0:
    name = readInput(maxLength = aliasNameLength)
    if name.len() == 0:
      discard showError(message = "Please enter a name for the alias.")
    elif not validIdentifier(s = $name):
      try:
        name.setString("")
        discard showError(message = "Please enter a valid name for the alias.")
      except CapacityError:
        discard showError(message = "Can't set empty name for alias.")
    if name.len() == 0:
      showOutput(message = "Name: ", newLine = false)
  if name == "exit":
    return showError(message = "Adding a new alias cancelled.")
  showFormHeader(message = "(2/6) Description")
  showOutput(message = "The description of the alias. It will be show on the list of available aliases and in the alias details. For example: 'List content of the directory.'. Can't contains a new line character. Can be empty.: ")
  showOutput(message = "Description: ", newLine = false)
  let description: UserInput = readInput()
  if description == "exit":
    return showError(message = "Adding a new alias cancelled.")
  showFormHeader(message = "(3/6) Working directory")
  showOutput(message = "The full path to the directory in which the alias will be available. If you want to have a global alias, set it to '/'. Can't be empty and must be a path to the existing directory.: ")
  showOutput(message = "Path: ", newLine = false)
  var path: DirectoryPath = "".DirectoryPath
  while path.len() == 0:
    path = DirectoryPath($readInput())
    if path.len() == 0:
      discard showError(message = "Please enter a path for the alias.")
    elif not dirExists(dir = $path) and path != "exit":
      path = "".DirectoryPath
      discard showError(message = "Please enter a path to the existing directory")
    if path.len() == 0:
      showOutput(message = "Path: ", newLine = false)
  if path == "exit":
    return showError(message = "Adding a new alias cancelled.")
  showFormHeader(message = "(4/6) Recursiveness")
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
  showFormHeader(message = "(5/6) Commands")
  showOutput(message = "The commands which will be executed when the alias is invoked. If you want to execute more than one command, you can merge them with '&&' or '||'. For example: 'clear && ls -a'. Commands can't contain a new line character. Can't be empty.:")
  showOutput(message = "Command(s): ", newLine = false)
  var commands: UserInput = emptyLimitedString(capacity = maxInputLength)
  while commands.len() == 0:
    commands = readInput()
    if commands.len() == 0:
      discard showError(message = "Please enter commands for the alias.")
      showOutput(message = "Command(s): ", newLine = false)
  if commands == "exit":
    return showError(message = "Adding a new alias cancelled.")
  showFormHeader(message = "(6/6) Output")
  showOutput(message = "Where should be redirected the alias output. Possible values are stdout (standard output, default), stderr (standard error) or path to the file to which output will be append. For example: 'output.txt'.")
  var output: UserInput = readInput()
  if output == "exit":
    return showError(message = "Adding a new alias cancelled.")
  elif output == "":
    try:
      output.setString(text = "stdout")
    except CapacityError:
      return showError(message = "Adding a new alias cancelled. Reason: Can't set output for the alias")
  # Check if alias with the same parameters exists in the database
  try:
    if db.getValue(query = sql(query = "SELECT id FROM aliases WHERE name=? AND path=? AND recursive=? AND commands=?"),
        name, path, recursive, commands).len() > 0:
      return showError(message = "There is an alias with the same name, path and commands in the database.")
  except DbError:
    return showError(message = "Can't check if the similar alias exists. Reason: ",
        e = getCurrentException())
  # Save the alias to the database
  try:
    if db.tryInsertID(query = sql(query = "INSERT INTO aliases (name, path, recursive, commands, description, output) VALUES (?, ?, ?, ?, ?, ?)"),
        name, path, recursive, commands, description, output) == -1:
      return showError(message = "Can't add alias.")
  except DbError:
    return showError(message = "Can't add the alias to the database. Reason: ",
        e = getCurrentException())
  # Update history index and refresh the list of available aliases
  historyIndex = updateHistory(commandToAdd = "alias add", db = db)
  try:
    aliases.setAliases(directory = getCurrentDir().DirectoryPath, db = db)
  except OSError:
    return showError(message = "Can't set aliases for the current directory. Reason: ",
        e = getCurrentException())
  showOutput(message = "The new alias '" & name & "' added.", fgColor = fgGreen)
  return QuitSuccess.ResultCode

proc editAlias*(arguments; historyIndex; aliases; db): ResultCode {.gcsafe,
    sideEffect, raises: [], tags: [ReadDbEffect, ReadIOEffect, WriteIOEffect,
        WriteDbEffect,
    ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Edit the selected alias
  ##
  ## PARAMETERS
  ##
  ## * arguments    - the user entered text with arguments for the editing
  ##                  alias
  ## * historyIndex - the index of the last command in the shell's history
  ## * aliases      - the list of aliases available in the current directory
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the alias was properly edited, otherwise QuitFailure.
  ## Also, updated parameters historyIndex and aliases.
  if arguments.len() < 6:
    return showError(message = "Enter the ID of the alias to edit.")
  let id: DatabaseId = try:
      parseInt(s = $arguments[5 .. ^1]).DatabaseId
    except ValueError:
      return showError(message = "The Id of the alias must be a positive number.")
  let row: Row = try:
        db.getRow(query = sql(query = "SELECT name, path, commands, description, output FROM aliases WHERE id=?"), id)
    except DbError:
      return showError(message = "The alias with the ID: " & $id & " doesn't exists.")
  showOutput(message = "You can cancel editing the alias at any time by double press Escape key. You can also reuse a current value by pressing Enter.")
  showFormHeader(message = "(1/6) Name")
  showOutput(message = "The name of the alias. Will be used to execute it. Current value: '",
      newLine = false)
  showOutput(message = row[0], newLine = false, fgColor = fgMagenta)
  showOutput(message = "'. Can contains only letters, numbers and underscores.")
  showOutput(message = "Name: ", newLine = false)
  var name: AliasName = readInput(maxLength = aliasNameLength)
  while name.len() > 0 and not validIdentifier(s = $name):
    discard showError(message = "Please enter a valid name for the alias.")
    name = readInput(maxLength = aliasNameLength)
  if name == "exit":
    return showError(message = "Editing the alias cancelled.")
  elif name == "":
    try:
      name.setString(text = row[0])
    except CapacityError:
      return showError(message = "Editing the alias cancelled. Reason: Can't set name for the alias")
  showFormHeader(message = "(2/6) Description")
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
      description.setString(text = row[3])
    except CapacityError:
      return showError(message = "Editing the alias cancelled. Reason: Can't set description for the alias")
  showFormHeader(message = "(3/6) Working directory")
  showOutput(message = "The full path to the directory in which the alias will be available. If you want to have a global alias, set it to '/'. Current value: '",
      newLine = false)
  showOutput(message = row[1], newLine = false, fgColor = fgMagenta)
  showOutput(message = "'. Must be a path to the existing directory.")
  var path: DirectoryPath = DirectoryPath($readInput())
  while path.len() > 0 and (path != "exit" and not dirExists(dir = $path)):
    discard showError(message = "Please enter a path to the existing directory")
    path = DirectoryPath($readInput())
  if path == "exit":
    return showError(message = "Editing the alias cancelled.")
  elif path == "":
    path = row[1].DirectoryPath
  showFormHeader(message = "(4/6) Recursiveness")
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
  showFormHeader(message = "(5/6) Commands")
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
      commands.setString(text = row[2])
    except CapacityError:
      return showError(message = "Editing the alias cancelled. Reason: Can't set commands for the alias")
  showFormHeader(message = "(6/6) Output")
  showOutput(message = "Where should be redirected the alias output. Possible values are stdout (standard output, default), stderr (standard error) or path to the file to which output will be append. Current value: '",
      newLine = false)
  showOutput(message = row[4], newLine = false, fgColor = fgMagenta)
  var output: UserInput = readInput()
  if output == "exit":
    return showError(message = "Editing the alias cancelled.")
  elif output == "":
    try:
      output.setString(text = row[4])
    except CapacityError:
      return showError(message = "Editing the alias cancelled. Reason: Can't set output for the alias")
  # Save the alias to the database
  try:
    if db.execAffectedRows(query = sql(query = "UPDATE aliases SET name=?, path=?, recursive=?, commands=?, description=?, output=? where id=?"),
        name, path, recursive, commands, description, output, id) != 1:
      return showError(message = "Can't edit the alias.")
  except DbError:
    return showError(message = "Can't save the alias to database. Reason: ",
        e = getCurrentException())
  # Update history index and refresh the list of available aliases
  historyIndex = updateHistory(commandToAdd = "alias edit", db = db)
  try:
    aliases.setAliases(directory = getCurrentDir().DirectoryPath, db = db)
  except OSError:
    return showError(message = "Can't set aliases for the current directory. Reason: ",
        e = getCurrentException())
  showOutput(message = "The alias  with Id: '" & $id & "' edited.",
      fgColor = fgGreen)
  return QuitSuccess.ResultCode

proc execAlias*(arguments; aliasId: string; aliases; db): ResultCode {.gcsafe,
    sideEffect, raises: [], tags: [ReadEnvEffect, ReadIOEffect, ReadDbEffect,
    WriteIOEffect, ExecIOEffect, RootEffect].} =
  ## FUNCTION
  ##
  ## Execute the selected by the user alias. If it is impossible due to lack
  ## of needed arguments or other errors, print information about it.
  ##
  ## PARAMETERS
  ##
  ## * arguments - the user entered text with arguments for executing the
  ##               alias
  ## * aliasId   - the id of the alias which will be executed
  ## * aliases   - the list of aliases available in the current directory
  ## * db        - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the alias was properly executed, otherwise QuitFailure.
  ## Also, updated parameter aliases.

  proc changeDirectory(newDirectory: DirectoryPath; aliases;
      db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [ReadEnvEffect,
          ReadIOEffect, ReadDbEffect, WriteIOEffect, ReadEnvEffect,
              TimeEffect].} =
    ## FUNCTION
    ##
    ## Change the current directory for the shell
    ##
    ## PARAMETERS
    ##
    ## * newDirectory - the new directory to which the current directory will
    ##                  be changed
    ## * aliases      - the list of aliases available in the current directory
    ## * db           - the connection to the shell's database
    ##
    ## RETURNS
    ##
    ## QuitSuccess if the current directory was successfully changed, otherwise
    ## QuitFailure. Also, updated parameter aliases.
    let path: DirectoryPath = try:
        expandFilename(filename = absolutePath(path = expandTilde(
            path = $newDirectory))).DirectoryPath
      except OSError, ValueError:
        return showError(message = "Can't change directory. Reason: ",
            e = getCurrentException())
    try:
      setCurrentDir(newDir = $path)
      aliases.setAliases(directory = path, db = db)
      return QuitSuccess.ResultCode
    except OSError:
      return showError(message = "Can't change directory. Reason: ",
          e = getCurrentException())

  let
    currentDirectory: DirectoryPath = try:
        getCurrentDir().DirectoryPath
      except OSError:
        return showError(message = "Can't get the current directory name. Reason: ",
            e = getCurrentException())
    commandArguments: seq[string] = (if arguments.len() > 0: initOptParser(
        cmdline = $arguments).remainingArgs() else: @[])
    aliasIndex: LimitedString = try:
        initLimitedString(capacity = maxInputLength, text = aliasId)
      except CapacityError:
        return showError(message = "Can't set alias index for " & aliasId)
  var inputString: string = try:
      db.getValue(query = sql(query = "SELECT commands FROM aliases WHERE id=?"),
          aliases[aliasIndex])
    except KeyError, DbError:
      return showError(message = "Can't get commands for alias. Reason: ",
          e = getCurrentException())
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
    if argumentNumber > commandArguments.len():
      return showError(message = "Not enough arguments entered")
    elif argumentNumber > 0:
      inputString = inputString.replace(sub = inputString[
        argumentPosition..argumentPosition + 1], by = commandArguments[
            argumentNumber - 1])
    else:
      inputString = inputString.replace(sub = inputString[
        argumentPosition..argumentPosition + 1], by = commandArguments.join(sep = " "))
    argumentPosition = inputString.find(sub = '$', start = argumentPosition + 1)
  # Execute the selected alias
  while inputString.len() > 0:
    var
      conjCommands: bool
      userInput: OptParser = initOptParser(cmdline = inputString)
    let
      command: UserInput = getArguments(userInput = userInput,
          conjCommands = conjCommands)
    inputString = join(a = userInput.remainingArgs(), sep = " ")
    # Threat cd command specially, it should just change the current
    # directory for the alias
    if command[0..2] == "cd ":
      if changeDirectory(newDirectory = DirectoryPath($command[3..^1]),
          aliases = aliases, db = db) != QuitSuccess and conjCommands:
        return QuitFailure.ResultCode
      continue
    if execCmd($command) != QuitSuccess and conjCommands:
      return QuitFailure.ResultCode
    if not conjCommands:
      break
  return changeDirectory(newDirectory = currentDirectory, aliases = aliases, db = db)

proc initAliases*(helpContent: var HelpTable; db): AliasesList {.gcsafe,
    sideEffect, raises: [], tags: [ReadDbEffect, WriteIOEffect, ReadEnvEffect,
    TimeEffect].} =
  ## FUNCTION
  ##
  ## Initialize the shell's aliases. Set help related to the aliases and
  ## load aliases available in the current directory
  ##
  ## PARAMETERS
  ##
  ## * helpContent - the HelpTable with help content of the shell
  ## * db          - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## The list of available aliases in the current directory and the updated
  ## helpContent with the help for the commands related to the shell's
  ## aliases.
  helpContent["alias"] = HelpEntry(usage: "alias ?subcommand?",
      content: "If entered without subcommand, show the list of available subcommands for aliases. Otherwise, execute the selected subcommand.")
  helpContent["alias list"] = HelpEntry(usage: "alias list ?all?",
      content: "Show the list of all available aliases in the current directory. If parameter all added, show all declared aliases.")
  helpContent["alias delete"] = HelpEntry(usage: "alias delete [index]",
      content: "Delete the alias with the selected index.")
  helpContent["alias show"] = HelpEntry(usage: "alias show [index]",
      content: "Show details (description, commands, etc) for the alias with the selected index.")
  helpContent["alias add"] = HelpEntry(usage: "alias add",
      content: "Start adding a new alias to the shell. You will be able to set its name, description, commands, etc.")
  helpContent["alias edit"] = HelpEntry(usage: "alias edit [index]",
      content: "Start editing the alias with the selected index. You will be able to set again its all parameters.")
  try:
    result.setAliases(directory = getCurrentDir().DirectoryPath, db = db)
  except OSError:
    discard showError(message = "Can't initialize aliases. Reason: ",
        e = getCurrentException())

proc updateAliasesDb*(db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect], locks: 0.} =
  ## FUNCTION
  ##
  ## Update the table aliases to the new version if needed
  ##
  ## PARAMETERS
  ##
  ## * db - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if update was successfull, otherwise QuitFailure and
  ## show message what wrong
  try:
    db.exec(query = sql(query = """ALTER TABLE aliases ADD output VARCHAR(""" & $maxInputLength &
                """) NOT NULL DEFAULT 'stdout'"""))
  except DbError:
    return showError(message = "Can't update table for the shell's aliases. Reason: ",
        e = getCurrentException())
  return QuitSuccess.ResultCode

proc createAliasesDb*(db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect], locks: 0.} =
  ## FUNCTION
  ##
  ## Create the table aliases
  ##
  ## PARAMETERS
  ##
  ## * db - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if creation was successfull, otherwise QuitFailure and
  ## show message what wrong
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

