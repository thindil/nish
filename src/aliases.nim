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
import constants, history, input, output

using
  db: DbConn # Connection to the shell's database
  aliases: var OrderedTable[string, int] # The list of aliases available in the selected directory
  arguments: string # The string with arguments entered by the user fot the command
  historyIndex: var int # The index of the last command in the shell's history

proc setAliases*(aliases; directory: string; db) {.gcsafe, sideEffect, raises: [], tags: [ReadDbEffect,
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
  aliases.clear()
  var
    dbQuery: string = "SELECT id, name FROM aliases WHERE path='" & directory & "'"
    remainingDirectory: string = parentDir(directory)

  # Construct SQL querry, search for aliases also defined in parent directories
  # if they are recursive
  while remainingDirectory != "":
    dbQuery.add(" OR (path='" & remainingDirectory & "' AND recursive=1)")
    remainingDirectory = parentDir(remainingDirectory)
  dbQuery.add(" ORDER BY id ASC")
  # Set the aliases
  try:
    for dbResult in db.fastRows(sql(dbQuery)):
      try:
        aliases[dbResult[1]] = parseInt(dbResult[0])
      except ValueError:
        discard showError("Can't set alias, invalid Id: " & dbResult[0])
  except DbError as e:
    discard showError("Can't set aliases for the current directory. Reason: " & e.msg)

proc listAliases*(arguments; historyIndex; aliases: OrderedTable[string, int];
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
    columnLength: int = try: db.getValue(
        sql"SELECT name FROM aliases ORDER BY LENGTH(name) DESC LIMIT 1").len() except DbError: 10
    spacesAmount: Natural = try: (terminalWidth() / 12).int except ValueError: 6
  if arguments == "list":
    showFormHeader("Available aliases are:")
    try:
      showOutput(message = indent("ID   $1 Description" % [alignLeft("Name",
        columnLength)], spacesAmount), fgColor = fgMagenta)
    except ValueError:
      showOutput(message = indent("ID   Name Description", spacesAmount),
          fgColor = fgMagenta)
    for alias in aliases.values:
      try:
        let row: Row = db.getRow(sql"SELECT id, name, description FROM aliases WHERE id=?",
          alias)
        showOutput(indent(alignLeft(row[0], 4) & " " & alignLeft(row[1],
            columnLength) & " " & row[2], spacesAmount))
      except DbError as e:
        discard showError("Can't read info about alias from database. Reason:" & e.msg)
        return
    historyIndex = updateHistory("alias list", db)
  elif arguments == "list all":
    showFormHeader("All available aliases are:")
    try:
      showOutput(message = indent("ID   $1 Description" % [alignLeft("Name",
          columnLength)], spacesAmount), fgColor = fgMagenta)
    except ValueError:
      showOutput(message = indent("ID   Name Description", spacesAmount),
          fgColor = fgMagenta)
    try:
      for row in db.fastRows(sql"SELECT id, name, description FROM aliases"):
        showOutput(indent(alignLeft(row[0], 4) & " " & alignLeft(row[1],
            columnLength) & " " & row[2], spacesAmount))
    except DbError as e:
      discard showError("Can't read info about alias from database. Reason:" & e.msg)
      return
    historyIndex = updateHistory("alias list all", db)

proc deleteAlias*(arguments; historyIndex; aliases; db): int {.gcsafe,
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
    historyIndex = updateHistory("alias delete", db, QuitFailure)
    return showError("Enter the Id of the alias to delete.")
  let id: string = arguments[7 .. ^1]
  try:
    if db.execAffectedRows(sql"DELETE FROM aliases WHERE id=?", id) == 0:
      historyIndex = updateHistory("alias delete", db, QuitFailure)
      return showError("The alias with the Id: " & id &
        " doesn't exists.")
  except DbError as e:
    return showError("Can't delete alias from database. Reason: " & e.msg)
  historyIndex = updateHistory("alias delete", db)
  try:
    aliases.setAliases(getCurrentDir(), db)
  except OSError as e:
    return showError("Can't delete alias, setting a new aliases not work. Reason: " & e.msg)
  showOutput(message = "Deleted the alias with Id: " & id, fgColor = fgGreen)
  return QuitSuccess

proc showAlias*(arguments; historyIndex; aliases: OrderedTable[string, int];
    db): int {.gcsafe, sideEffect, raises: [], tags: [
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
    historyIndex = updateHistory("alias show", db, QuitFailure)
    return showError("Enter the ID of the alias to show.")
  let
    id: string = arguments[5 .. ^1]
    row: Row = (try: db.getRow(sql"SELECT name, commands, description, path, recursive FROM aliases WHERE id=?",
      id) except DbError as e: return showError(
          "Can't read alias data from database. Reason: " & e.msg))
  if row[0] == "":
    historyIndex = updateHistory("alias show", db, QuitFailure)
    return showError("The alias with the ID: " & id &
      " doesn't exists.")
  historyIndex = updateHistory("alias show", db)
  let spacesAmount: Natural = (try: (terminalWidth() /
      12).int except ValueError: 6)
  showOutput(message = indent(alignLeft("Id:", 13), spacesAmount),
      newLine = false, fgColor = fgMagenta)
  showOutput(id)
  showOutput(message = indent(alignLeft("Name:", 13), spacesAmount),
      newLine = false, fgColor = fgMagenta)
  showOutput(row[0])
  showOutput(message = indent("Description: ", spacesAmount), newLine = false,
      fgColor = fgMagenta)
  showOutput(row[2])
  if row[4] == "1":
    showOutput(message = indent(alignLeft("Path:", 13), spacesAmount),
        newLine = false, fgColor = fgMagenta)
    showOutput(row[3] & " (recursive)")
  else:
    showOutput(message = indent(alignLeft("Path:", 13), spacesAmount),
        newLine = false, fgColor = fgMagenta)
    showOutput(row[3])
  showOutput(message = indent(alignLeft("Command(s):", 13), spacesAmount),
      newLine = false, fgColor = fgMagenta)
  showOutput(row[1])
  return QuitSuccess

proc helpAliases*(db): int {.gcsafe, sideEffect, raises: [], tags: [
    ReadDbEffect, WriteDbEffect, ReadIOEffect, WriteIOEffect, ReadEnvEffect,
    TimeEffect].} =
  ## FUNCTION
  ##
  ## Show short help about available subcommands related to the aliases
  ##
  ## PARAMETERS
  ##
  ## * db           - the connection to the shell's database
  showOutput("""Available subcommands are: list, delete, show, add, edit

        To see more information about the subcommand, type help alias [command],
        for example: help alias list.
""")
  return updateHistory("alias", db)

proc addAlias*(historyIndex; aliases; db): int {.gcsafe, sideEffect, raises: [],
    tags: [ReadDbEffect, ReadIOEffect, WriteIOEffect, WriteDbEffect,
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
  showOutput("You can cancel adding a new alias at any time by double press Escape key.")
  showFormHeader("(1/5) Name")
  showOutput("The name of the alias. Will be used to execute it. For example: 'ls'. Can't be empty and can contains only letters, numbers and underscores:")
  var name: string = ""
  showOutput("Name: ", false)
  while name.len() == 0:
    name = readInput(aliasNameLength)
    if name.len() == 0:
      discard showError("Please enter a name for the alias.")
    elif not name.validIdentifier:
      name = ""
      discard showError("Please enter a valid name for the alias.")
    if name.len() == 0:
      showOutput("Name: ", false)
  if name == "exit":
    return showError("Adding a new alias cancelled.")
  showFormHeader("(2/5) Description")
  showOutput("The description of the alias. It will be show on the list of available aliases and in the alias details. For example: 'List content of the directory.'. Can't contains a new line character. Can be empty.: ")
  showOutput("Description: ", false)
  let description: string = readInput()
  if description == "exit":
    return showError("Adding a new alias cancelled.")
  showFormHeader("(3/5) Working directory")
  showOutput("The full path to the directory in which the alias will be available. If you want to have a global alias, set it to '/'. Can't be empty and must be a path to the existing directory.: ")
  showOutput("Path: ", false)
  var path: string = ""
  while path.len() == 0:
    path = readInput()
    if path.len() == 0:
      discard showError("Please enter a path for the alias.")
    elif not dirExists(path) and path != "exit":
      path = ""
      discard showError("Please enter a path to the existing directory")
    if path.len() == 0:
      showOutput("Path: ", false)
  if path == "exit":
    return showError("Adding a new alias cancelled.")
  showFormHeader("(4/5) Recursiveness")
  showOutput("Select if alias is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press 'y' or 'n':")
  showOutput("Recursive(y/n): ", false)
  var inputChar: char = (try: getch() except IOError: 'y')
  while inputChar notin {'n', 'N', 'y', 'Y'}:
    inputChar = (try: getch() except IOError: 'y')
  showOutput($inputChar)
  let recursive: int = if inputChar in {'n', 'N'}: 0 else: 1
  showFormHeader("(5/5) Commands")
  showOutput("The commands which will be executed when the alias is invoked. If you want to execute more than one command, you can merge them with '&&' or '||'. For example: 'clear && ls -a'. Commands can't contain a new line character. Can't be empty.:")
  showOutput("Command(s): ", false)
  var commands: string = ""
  while commands.len() == 0:
    commands = readInput()
    if commands.len() == 0:
      discard showError("Please enter commands for the alias.")
      showOutput("Command(s): ", false)
  if commands == "exit":
    return showError("Adding a new alias cancelled.")
  # Check if alias with the same parameters exists in the database
  try:
    if db.getValue(sql"SELECT id FROM aliases WHERE name=? AND path=? AND recursive=? AND commands=?",
        name, path, recursive, commands).len() > 0:
      return showError("There is an alias with the same name, path and commands in the database.")
  except DbError as e:
    return showError("Can't check if the similar alias exists. Reason: " & e.msg)
  # Save the alias to the database
  try:
    if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
        name, path, recursive, commands, description) == -1:
      return showError("Can't add alias.")
  except DbError as e:
    return showError("Can't add the alias to the database. Reason: " & e.msg)
  # Update history index and refresh the list of available aliases
  historyIndex = updateHistory("alias add", db)
  try:
    aliases.setAliases(getCurrentDir(), db)
  except OSError as e:
    return showError("Can't set aliases for the current directory. Reason: " & e.msg)
  showOutput(message = "The new alias '" & name & "' added.", fgColor = fgGreen)
  return QuitSuccess

proc editAlias*(arguments; historyIndex; aliases; db): int {.gcsafe,
        sideEffect, raises: [EOFError, OSError, IOError], tags: [
        ReadDbEffect, ReadIOEffect, WriteIOEffect, WriteDbEffect, ReadEnvEffect,
            TimeEffect].} =
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
    return showError("Enter the ID of the alias to edit.")
  let
    id: string = arguments[5 .. ^1]
    row: Row = db.getRow(sql"SELECT name, path, commands, description FROM aliases WHERE id=?",
    id)
  if row[0] == "":
    return showError("The alias with the ID: " & id & " doesn't exists.")
  showOutput("You can cancel editing the alias at any time by double press Escape key. You can also reuse a current value by pressing Enter.")
  showFormHeader("(1/5) Name")
  showOutput(message = "The name of the alias. Will be used to execute it. Current value: '",
      newLine = false)
  showOutput(message = row[0], newLine = false, fgColor = fgMagenta)
  showOutput("'. Can contains only letters, numbers and underscores.")
  showOutput("Name: ", false)
  var name: string = readInput(aliasNameLength)
  while name.len() > 0 and not name.validIdentifier:
    discard showError("Please enter a valid name for the alias.")
    name = readInput(aliasNameLength)
  if name == "exit":
    return showError("Editing the alias cancelled.")
  elif name == "":
    name = row[0]
  showFormHeader("(2/5) Description")
  showOutput(message = "The description of the alias. It will be show on the list of available aliases and in the alias details. Current value: '",
      newLine = false)
  showOutput(message = row[3], newLine = false, fgColor = fgMagenta)
  showOutput("'. Can't contains a new line character.: ")
  showOutput("Description: ", false)
  var description: string = readInput()
  if description == "exit":
    return showError("Editing the alias cancelled.")
  elif description == "":
    description = row[3]
  showFormHeader("(3/5) Working directory")
  showOutput(message = "The full path to the directory in which the alias will be available. If you want to have a global alias, set it to '/'. Current value: '",
      newLine = false)
  showOutput(message = row[1], newLine = false, fgColor = fgMagenta)
  showOutput("'. Must be a path to the existing directory.")
  var path: string = readInput()
  while path.len() > 0 and (path != "exit" and not dirExists(path)):
    discard showError("Please enter a path to the existing directory")
    path = readInput()
  if path == "exit":
    return showError("Editing the alias cancelled.")
  elif path == "":
    path = row[1]
  showFormHeader("(4/5) Recursiveness")
  showOutput("Select if alias is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press 'y' or 'n':")
  showOutput("Recursive(y/n): ", false)
  var inputChar: char = getch()
  while inputChar != 'n' and inputChar != 'N' and inputChar != 'y' and
      inputChar != 'Y':
    inputChar = getch()
  let recursive: int = if inputChar == 'n' or inputChar == 'N': 0 else: 1
  stdout.writeLine("")
  showFormHeader("(5/5) Commands")
  showOutput(message = "The commands which will be executed when the alias is invoked. If you want to execute more than one command, you can merge them with '&&' or '||'. Current value: '",
      newLine = false)
  showOutput(message = row[2], newLine = false, fgColor = fgMagenta)
  showOutput(message = "'. Commands can't contain a new line character.:")
  showOutput("Commands: ", false)
  var commands: string = readInput()
  if commands == "exit":
    return showError("Editing the alias cancelled.")
  elif commands == "":
    commands = row[2]
  # Save the alias to the database
  if db.execAffectedRows(sql"UPDATE aliases SET name=?, path=?, recursive=?, commands=?, description=? where id=?",
      name, path, recursive, commands, description, id) != 1:
    return showError("Can't edit the alias.")
  # Update history index and refresh the list of available aliases
  historyIndex = updateHistory("alias edit", db)
  aliases.setAliases(getCurrentDir(), db)
  showOutput(message = "The alias  with Id: '" & id & "' edited.",
      fgColor = fgGreen)
  return QuitSuccess

proc execAlias*(arguments; aliasId: string; aliases; db): int{.gcsafe,
        sideEffect, raises: [DbError, ValueError, OSError], tags: [
            ReadEnvEffect, ReadIOEffect, ReadDbEffect, WriteIOEffect,
            ExecIOEffect,
        RootEffect].} =
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
  proc changeDirectory(newDirectory: string; aliases; db): int {.gcsafe,
    sideEffect, raises: [ValueError, OSError], tags: [ReadEnvEffect, ReadIOEffect, ReadDbEffect,
              WriteIOEffect, ReadEnvEffect, TimeEffect].} =
    ## Change the current directory for the shell
    let path: string = expandFilename(absolutePath(expandTilde(newDirectory)))
    try:
      setCurrentDir(path)
      aliases.setAliases(path, db)
      return QuitSuccess
    except OSError:
      return showError()

  let
    currentDirectory: string = getCurrentDir()
    commandArguments: seq[string] = initOptParser(arguments).remainingArgs()
  var inputString: string = db.getValue(
      sql"SELECT commands FROM aliases WHERE id=?", aliases[aliasId])
  # Convert all $number in commands to arguments taken from the user
  # input
  var
    argumentPosition: int = inputString.find('$')
  while argumentPosition > -1:
    var argumentNumber: int = parseInt(inputString[argumentPosition + 1] & "")
    # Not enough argument entered by the user, quit with error
    if argumentNumber > commandArguments.len():
      return showError("Not enough arguments entered")
    elif argumentNumber > 0:
      inputString = inputString.replace(inputString[
        argumentPosition..argumentPosition + 1], commandArguments[
            argumentNumber - 1])
    else:
      inputString = inputString.replace(inputString[
        argumentPosition..argumentPosition + 1], commandArguments.join(" "))
    argumentPosition = inputString.find('$')
  while inputString.len() > 0:
    var
      conjCommands: bool
      userInput: OptParser = initOptParser(inputString)
    let
      command: string = getArguments(userInput, conjCommands)
    inputString = join(userInput.remainingArgs(), " ")
    # Threat cd command specially, it should just change the current
    # directory for the alias
    if command[0..2] == "cd ":
      if changeDirectory(command[3..^1], aliases, db) != QuitSuccess and conjCommands:
        return QuitFailure
      continue
    if execCmd(command) != QuitSuccess and conjCommands:
      return QuitFailure
    if not conjCommands:
      break
  return changeDirectory(currentDirectory, aliases, db)

proc initAliases*(helpContent: var HelpTable; db): OrderedTable[string,
    int] {.gcsafe, sideEffect, raises: [], tags: [ReadDbEffect,
        WriteIOEffect, ReadEnvEffect, TimeEffect].} =
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
    result.setAliases(getCurrentDir(), db)
  except OSError as e:
    discard showError("Can't initialize aliases. Reason: " & e.msg)
