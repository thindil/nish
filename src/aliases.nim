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

func setAliases*(aliases: var OrderedTable[string, int]; directory: string;
    db: DbConn) {.gcsafe, raises: [ValueError, DbError], tags: [
    ReadDbEffect].} =
  ## Set the available aliases in the selected directory
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
  for dbResult in db.fastRows(sql(dbQuery)):
    aliases[dbResult[1]] = parseInt(dbResult[0])

proc listAliases*(arguments: string; historyIndex: var int;
    aliases: OrderedTable[string, int]; db: DbConn) {.gcsafe, sideEffect,
        locks: 0, raises: [IOError, OSError, ValueError], tags: [ReadIOEffect,
        WriteIOEffect, ReadDbEffect, WriteDbEffect].} =
  ## List available aliases, if entered command was "alias list all" list all
  ## declared aliases then
  showOutput("Available aliases are:")
  showOutput("ID Name Description")
  if arguments == "list":
    historyIndex = updateHistory("alias list", db)
    for alias in aliases.values:
      let row = db.getRow(sql"SELECT id, name, description FROM aliases WHERE id=?",
        alias)
      showOutput(row[0] & " " & row[1] & " " & row[2])
  elif arguments == "list all":
    historyIndex = updateHistory("alias list all", db)
    for row in db.fastRows(sql"SELECT id, name, description FROM aliases"):
      showOutput(row[0] & " " & row[1] & " " & row[2])

proc deleteAlias*(arguments: string; historyIndex: var int;
    aliases: var OrderedTable[string, int]; db: DbConn): int {.gcsafe,
        sideEffect, raises: [IOError, ValueError, OSError], tags: [
        WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect].} =
  ## Delete the selected alias from the shell's database
  if arguments.len() < 8:
    historyIndex = updateHistory("alias delete", db, QuitFailure)
    return showError("Enter the Id of the alias to delete.")
  let id = arguments[7 .. ^1]
  if db.execAffectedRows(sql"DELETE FROM aliases WHERE id=?", id) == 0:
    historyIndex = updateHistory("alias delete", db, QuitFailure)
    return showError("The alias with the Id: " & id &
      " doesn't exists.")
  historyIndex = updateHistory("alias delete", db)
  aliases.setAliases(getCurrentDir(), db)
  showOutput("Deleted the alias with Id: " & id)
  return QuitSuccess

proc showAlias*(arguments: string; historyIndex: var int;
    aliases: var OrderedTable[string, int]; db: DbConn): int {.gcsafe,
        sideEffect, raises: [IOError, ValueError, OSError], tags: [
        WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect].} =
  ## Show details about the selected alias, its ID, name, description and
  ## commands which will be executed
  if arguments.len() < 6:
    historyIndex = updateHistory("alias show", db, QuitFailure)
    return showError("Enter the ID of the alias to show.")
  let
    id = arguments[5 .. ^1]
    row = db.getRow(sql"SELECT name, commands, description, path, recursive FROM aliases WHERE id=?",
      id)
  if row[0] == "":
    historyIndex = updateHistory("alias show", db, QuitFailure)
    return showError("The alias with the ID: " & id &
      " doesn't exists.")
  historyIndex = updateHistory("alias show", db)
  showOutput("Id: " & id)
  showOutput("Name: " & row[0])
  showOutput("Description: " & row[2])
  if row[4] == "1":
    showOutput("Path: " & row[3] & " (recursive)")
  else:
    showOutput("Path: " & row[3])
  showOutput("Commands: ")
  showOutput(row[1])
  return QuitSuccess

proc helpAliases*(db: DbConn): int {.gcsafe, sideEffect, locks: 0, raises: [
    DbError, OSError, IOError, ValueError], tags: [ReadDbEffect, WriteDbEffect,
    ReadIOEffect, WriteIOEffect].} =
  ## Show short help about available subcommands related to the aliases
  showOutput("""Available subcommands are: list, delete, show, add, edit

        To see more information about the subcommand, type help alias [command],
        for example: help alias list.
""")
  return updateHistory("alias", db)

proc addAlias*(historyIndex: var int;
    aliases: var OrderedTable[string, int]; db: DbConn): int {.gcsafe,
        sideEffect, raises: [EOFError, OSError, IOError, ValueError], tags: [
        ReadDbEffect, ReadIOEffect, WriteIOEffect, WriteDbEffect].} =
  ## Add a new alias to the shell. Ask the user a few questions and fill the
  ## alias values with answers
  showOutput("You can cancel adding a new alias at any time by double press Escape key.")
  showOutput("The name of the alias. Will be used to execute it. For example: 'ls'.:")
  let name = readInput(aliasNameLength)
  if name == "exit":
    return showError("Adding a new alias cancelled.")
  showOutput("The description of the alias. It will be show on the list of available aliases and in the alias details. For example: 'List content of the directory.'. Can't contains a new line character.: ")
  let description = readInput()
  if description == "exit":
    return showError("Adding a new alias cancelled.")
  showOutput("The full path to the directory in which the alias will be available. If you want to have a global alias, set it to '/'.: ")
  let path = readInput()
  if path == "exit":
    return showError("Adding a new alias cancelled.")
  showOutput("Select if alias is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press 'y' or 'n':")
  var inputChar: char = getch()
  while inputChar != 'n' and inputChar != 'N' and inputChar != 'y' and
      inputChar != 'Y':
    inputChar = getch()
  let recursive = if inputChar == 'n' or inputChar == 'N': 0 else: 1
  stdout.writeLine("")
  showOutput("The commands which will be executed when the alias is invoked. If you want to execute more than one command, separate them with ';'. For example: 'clear; ls -a'. Commands can't contain a new line character.:")
  let commands = replace(readInput(), "; ", "\\n")
  if commands == "exit":
    return showError("Adding a new alias cancelled.")
  # Save the alias to the database
  if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
      name, path, recursive, commands, description) == -1:
    return showError("Can't add alias.")
  # Update history index and refresh the list of available aliases
  historyIndex = updateHistory("alias add", db)
  aliases.setAliases(getCurrentDir(), db)
  return QuitSuccess

proc editAlias*(arguments: string; historyIndex: var int;
    aliases: var OrderedTable[string, int]; db: DbConn): int {.gcsafe,
        sideEffect, raises: [EOFError, OSError, IOError, ValueError], tags: [
        ReadDbEffect, ReadIOEffect, WriteIOEffect, WriteDbEffect].} =
  ## Edit the selected alias
  if arguments.len() < 6:
    return showError("Enter the ID of the alias to edit.")
  let
    id = arguments[5 .. ^1]
    row = db.getRow(sql"SELECT name, path, commands, description FROM aliases WHERE id=?",
    id)
  if row[0] == "":
    return showError("The alias with the ID: " & id & " doesn't exists.")
  showOutput("You can cancel editing the alias at any time by double press Escape key. You can also reuse a current value by pressing Enter.")
  showOutput("The name of the alias. Will be used to execute it. Current value: '" &
      row[0] & "'")
  var name = readInput(aliasNameLength)
  if name == "exit":
    return showError("Editing the alias cancelled.")
  elif name == "":
    name = row[0]
  showOutput("The description of the alias. It will be show on the list of available aliases and in the alias details. Current value: '" &
      row[3] & "'. Can't contains a new line character.: ")
  var description = readInput()
  if description == "exit":
    return showError("Editing the alias cancelled.")
  elif description == "":
    description = row[3]
  showOutput("The full path to the directory in which the alias will be available. If you want to have a global alias, set it to '/'. Current value: '" &
      row[1] & "'")
  var path = readInput()
  if path == "exit":
    return showError("Editing the alias cancelled.")
  elif path == "":
    path = row[1]
  showOutput("Select if alias is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press 'y' or 'n':")
  var inputChar: char = getch()
  while inputChar != 'n' and inputChar != 'N' and inputChar != 'y' and
      inputChar != 'Y':
    inputChar = getch()
  let recursive = if inputChar == 'n' or inputChar == 'N': 0 else: 1
  stdout.writeLine("")
  showOutput("The commands which will be executed when the alias is invoked. If you want to execute more than one command, separate them with ';'. Current value: '" &
      replace(row[2], "\\n", "; ") &
      "'. Commands can't contain a new line character.:")
  var commands = replace(readInput(), "; ", "\\n")
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
  return QuitSuccess

proc execAlias*(arguments: string; commandName: string;
    aliases: var OrderedTable[string, int]; db: DbConn): int{.gcsafe,
        sideEffect, raises: [DbError, ValueError, IOError, OSError], tags: [
        ReadEnvEffect, ReadIOEffect, ReadDbEffect, WriteIOEffect, ExecIOEffect,
        RootEffect].} =
  ## Execute the selected by the user alias. If it is impossible due to lack
  ## of needed arguments or other errors, print information about it.

  proc changeDirectory(newDirectory: string; aliases: var OrderedTable[string,
      int]; db: DbConn): int {.gcsafe, sideEffect, raises: [DbError, ValueError,
          IOError, OSError], tags: [ReadEnvEffect, ReadIOEffect, ReadDbEffect,
          WriteIOEffect].} =
    ## Change the current directory for the shell
    let path: string = expandFilename(absolutePath(expandTilde(newDirectory)))
    try:
      setCurrentDir(path)
      aliases.setAliases(path, db)
      return QuitSuccess
    except OSError:
      return showError()

  let
    currentDirectory = getCurrentDir()
    commandArguments: seq[string] = initOptParser(arguments).remainingArgs()
  for command in splitLines(db.getValue(
      sql"SELECT commands FROM aliases WHERE id=?",
      aliases[commandName])):
    # Convert all $number in command to arguments taken from the user
    # input
    var
      argumentPosition: int = command.find('$')
      newCommand: string = command
    while argumentPosition > -1:
      var argumentNumber: int = parseInt(command[argumentPosition + 1] & "")
      # Not enough argument entered by the user, quit with error
      if argumentNumber > commandArguments.len():
        return showError("Not enough arguments entered")
      newCommand = command.replace(command[
          argumentPosition..argumentPosition + 1], commandArguments[
              argumentNumber - 1])
      argumentPosition = newCommand.find('$')
    # Threat cd command specially, it should just change the current
    # directory for the alias
    if newCommand[0..2] == "cd ":
      if changeDirectory(newCommand[3..^1], aliases, db) != QuitSuccess:
        return QuitFailure
      continue
    if execCmd(newCommand) != QuitSuccess:
      return QuitFailure
  return changeDirectory(currentDirectory, aliases, db)

proc initAliases*(helpContent: var Table[string, string];
    db: DbConn): OrderedTable[string, int] {.gcsafe, sideEffect, raises: [
    OSError, ValueError, DbError], tags: [ReadDbEffect].} =
  ## Initialize the shell's aliases. Set help related to the aliases and
  ## load aliases available in the current directory
  helpContent["alias"] = """
        Usage: alias ?subcommand?

        If entered without subcommand, show the list of available subcommands
        for aliases. Otherwise, execute the selected subcommand.
        """
  helpContent["alias list"] = """
        Usage: alias list ?all?

        Show the list of all available aliases in the current directory. If parameter
        all added, show all declared aliases.
        """
  helpContent["alias delete"] = """
        Usage: alias delete [index]

        Delete the alias with the selected index.
        """
  helpContent["alias show"] = """
        Usage: alias show [index]

        Show details (description, commands, etc) for the alias with the selected index.
        """
  helpContent["alias add"] = """
        Usage: alias add

        Start adding a new alias to the shell. You will be able to set its name, description, commands, etc.
        """
  helpContent["alias edit"] = """
        Usage: alias edit [index]

        Start editing the alias with the selected index. You will be able to set again its all parameters.
        """
  result.setAliases(getCurrentDir(), db)
