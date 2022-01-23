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

import std/[db_sqlite, os, parseopt, strutils, tables, terminal]
import constants, history, output

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

proc listAliases*(userInput: var OptParser; historyIndex: var int;
    aliases: OrderedTable[string, int]; db: DbConn) {.gcsafe, sideEffect,
        locks: 0, raises: [IOError, OSError, ValueError], tags: [ReadIOEffect,
        WriteIOEffect, ReadDbEffect, WriteDbEffect].} =
  ## List available aliases, if entered command was "alias list all" list all
  ## declared aliases then
  showOutput("Available aliases are:", true, false, "", QuitSuccess)
  showOutput("ID Name Description", true, false, "",
    QuitSuccess)
  userInput.next()
  if userInput.kind == cmdEnd:
    historyIndex = updateHistory("alias list", db)
    for alias in aliases.values:
      let row = db.getRow(sql"SELECT id, name, description FROM aliases WHERE id=?",
        alias)
      showOutput(row[0] & " " & row[1] & " " & row[2], true, false, "",
        QuitSuccess)
  elif userInput.key == "all":
    historyIndex = updateHistory("alias list all", db)
    for row in db.fastRows(sql"SELECT id, name, description FROM aliases"):
      showOutput(row[0] & " " & row[1] & " " & row[2], true, false, "",
        QuitSuccess)

proc deleteAlias*(userInput: var OptParser; historyIndex: var int;
    aliases: var OrderedTable[string, int]; db: DbConn): int {.gcsafe,
        sideEffect, raises: [IOError, ValueError, OSError], tags: [
        WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect].} =
  ## Delete the selected alias from the shell's database
  userInput.next()
  if userInput.kind == cmdEnd:
    result = showError("Enter the Id of the alias to delete.")
  else:
    if db.execAffectedRows(sql"DELETE FROM aliases WHERE id=?",
        userInput.key) == 0:
      result = showError("The alias with the Id: " & userInput.key &
        " doesn't exists.")
    else:
      historyIndex = updateHistory("alias delete", db)
      aliases.setAliases(getCurrentDir(), db)
      showOutput("Deleted the alias with Id: " & userInput.key, true,
          false, "", QuitSuccess)
      result = QuitSuccess

proc showAlias*(userInput: var OptParser; historyIndex: var int;
    aliases: var OrderedTable[string, int]; db: DbConn): int {.gcsafe,
        sideEffect, raises: [IOError, ValueError, OSError], tags: [
        WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect].} =
  ## Show details about the selected alias, its ID, name, description and
  ## commands which will be executed
  userInput.next()
  if userInput.kind == cmdEnd:
    result = showError("Enter the Id of the alias to show.")
  else:
    let row = db.getRow(sql"SELECT name, commands, description, path, recursive FROM aliases WHERE id=?",
        userInput.key)
    if row[0] == "":
      result = showError("The alias with the Id: " & userInput.key &
        " doesn't exists.")
    else:
      historyIndex = updateHistory("alias show", db)
      showOutput("Id: " & userInput.key, true, false, "", QuitSuccess)
      showOutput("Name: " & row[0], true, false, "", QuitSuccess)
      showOutput("Description: " & row[2], true, false, "", QuitSuccess)
      if row[4] == "1":
        showOutput("Path: " & row[3] & " (recursive)", true, false, "", QuitSuccess)
      else:
        showOutput("Path: " & row[3], true, false, "", QuitSuccess)
      showOutput("Commands: ", true, false, "", QuitSuccess)
      showOutput(row[1], true, false, "", QuitSuccess)

proc helpAliases*(db: DbConn): int {.gcsafe, sideEffect, locks: 0, raises: [
    DbError, OSError, IOError, ValueError], tags: [ReadDbEffect, WriteDbEffect,
    ReadIOEffect, WriteIOEffect].} =
  ## Show short help about available subcommands related to the aliases
  showOutput("""Available subcommands are: list, delete, show, add

        To see more information about the subcommand, type help alias [command],
        for example: help alias list.
""", true, false, "", QuitSuccess)
  result = updateHistory("alias", db)

proc readInput(maxLength: int = maxInputLength): string =
  ## Read the user input. Used in adding a new alias or editing an existing
  # Get the user input and parse it
  var inputChar = '\0'
  # Read the user input until not meet new line character or the input
  # reach the maximum length
  while inputChar.ord() != 13 and result.len() < maxLength:
    # Backspace pressed, delete the last character from the user input
    if inputChar.ord() == 127:
      if result.len() > 0:
        result = result[0..^2]
        stdout.cursorBackward()
        stdout.write(" ")
        stdout.cursorBackward()
    elif inputChar.ord() == 27:
      inputChar = getch()
      if inputChar.ord() == 27:
        return "exit"
      else:
        continue
    # Visible character, add it to the user input string and show it in the
    # console
    elif inputChar.ord() > 31:
      stdout.write(inputChar)
      result.add(inputChar)
    inputChar = getch()
  stdout.writeLine("")

proc addAlias*(historyIndex: var int;
    aliases: var OrderedTable[string, int]; db: DbConn): int {.gcsafe,
        sideEffect, raises: [EOFError, OSError, IOError, ValueError], tags: [
        ReadDbEffect, ReadIOEffect, WriteIOEffect, WriteDbEffect].} =
  ## Add a new alias to the shell. Ask the user a few questions and fill the
  ## alias values with answers
  showOutput("You can cancel adding a new alias at any time by double press Escape key.",
      true, false, "", QuitSuccess)
  showOutput("The name of the alias. Will be used to execute it. For example: 'ls'.:",
      true, false, "", QuitSuccess)
  let name = readInput(aliasNameLength)
  if name == "exit":
    return showError("Adding a new alias cancelled.")
  showOutput("The description of the alias. It will be show on the list of available aliases and in the alias details. For example: 'List content of the directory.'. Can't contains a new line character.: ",
      true, false, "", QuitSuccess)
  let description = readInput()
  if description == "exit":
    return showError("Adding a new alias cancelled.")
  showOutput("The full path to the directory in which the alias will be available. If you want to have a global alias, set it to '/'.: ",
      true, false, "", QuitSuccess)
  let path = readInput()
  if path == "exit":
    return showError("Adding a new alias cancelled.")
  showOutput("Select if alias is recursive or not. If recursive, it will be available also in all subdirectories for path set above. Press 'y' or 'n':",
      true, false, "", QuitSuccess)
  var inputChar: char = getch()
  while inputChar != 'n' and inputChar != 'N' and inputChar != 'y' and
      inputChar != 'Y':
    inputChar = getch()
  let recursive = if inputChar == 'n' or inputChar == 'N': 0 else: 1
  stdout.writeLine("")
  showOutput("The commands which will be executed when the alias is invoked. If you want to execute more than one command, separate them with ';'. For example: 'clear; ls -a'. Commands can't contain a new line character.:",
      true, false, "", QuitSuccess)
  let commands = replace(readInput(), "; ", "\\n")
  if commands == "exit":
    return showError("Adding a new alias cancelled.")
  # Save the alias to the database
  if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
      name, path, recursive, commands, description) == -1:
    return showError("Can't add alias.")
  # Update history index and refresh the list of available aliases
  result = QuitSuccess
  historyIndex = updateHistory("alias add", db)
  aliases.setAliases(getCurrentDir(), db)
