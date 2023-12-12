# Copyright © 2023 Bartek Jasicki
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

## This module contains initialization code of the shell's theme. It is in a
## separate module to avoid circular dependencies.

# Standard library imports
import std/strutils
# External modules imports
import ansiparse, contracts, nancy, nimalyzer, termstyle
import norm/sqlite
# Internal imports
import commandslist, constants, help, lstring, output, resultcode, theme

using db: DbConn # Connection to the shell's database

proc showTheme*(db): ResultCode {.sideEffect, raises: [], tags: [
    WriteIOEffect, ReadIOEffect, ExecIOEffect, RootEffect], contractual.} =
  ## Show all the colors which can be set in the shell's theme
  ##
  ## * db - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the colors were correctly shown, otherwise
  ## QuitFailure.
  require:
    db != nil
  body:
    var table: TerminalTable = TerminalTable()
    try:
      let color: string = getColor(db = db, name = tableHeaders)
      table.add(parts = [style(ss = "Name", style = color), style(ss = "Value",
          style = color), style(ss = "Description", style = color)])
    except UnknownEscapeError, InsufficientInputError, FinalByteError:
      showError(message = "Can't show the shell's theme's colors. Reason: ",
          e = getCurrentException(), db = db)
      return QuitFailure.ResultCode
    showFormHeader(message = "The shell's theme colors are:", db = db)
    try:
      var cols: seq[Color] = @[newColor()]
      db.rawSelect(qry = "SELECT * FROM theme ORDER BY name ASC",
          objs = cols)
      for color in cols:
        var value: string = $color.cValue
        if color.underline:
          value &= ", underlined"
        if color.bold:
          value &= ", bold"
        if color.italic:
          value &= ", italic"
        for col in colors:
          if col.name == color.name and (col.cValue != color.cValue or
              col.underline != color.underline or col.bold != color.bold or
              col.italic != color.italic):
            value &= " (changed)"
            break
        table.add(parts = [style(ss = color.name, style = getColor(db = db,
            name = ids)), style(ss = value, style = getColor(db = db,
            name = values)), style(ss = color.description, style = getColor(
            db = db, name = default))])
    except:
      showError(message = "Can't show the shell's theme's colors. Reason: ",
          e = getCurrentException(), db = db)
      return QuitFailure.ResultCode
    try:
      table.echoTable
    except IOError, Exception:
      showError(message = "Can't show the list of shell's theme's colors. Reason: ",
          e = getCurrentException(), db = db)
      return QuitFailure.ResultCode
    return QuitSuccess.ResultCode

proc setColor*(db; arguments: UserInput): ResultCode {.sideEffect, raises: [], tags: [
    WriteIOEffect, ReadIOEffect, ExecIOEffect, RootEffect], contractual.} =
  ## Set the value for the theme's color
  ##
  ## * db        - the connection to the shell's database
  ## * arguments - the arguments entered by the user for the command
  ##
  ## Returns QuitSuccess if the color was properly set, otherwise QuitFailure.
  require:
    db != nil
  body:
    let setting: seq[string] = ($arguments).split()
    if setting.len < 2:
      return showError(message = "Please enter name of the color and its new value.", db = db)
    if setting.len < 3:
      return showError(message = "Please enter a new value for the selected color.", db = db)
    return QuitSuccess.ResultCode

proc initTheme*(db: DbConn; commands: ref CommandsList) {.sideEffect, raises: [],
    tags: [ReadDbEffect, WriteIOEffect, TimeEffect, WriteDbEffect, RootEffect],
    contractual.} =
  ## Initialize the shell's theme. Set help related to the theme.
  ##
  ## * db          - the connection to the shell's database
  ## * commands    - the list of the shell's commands
  ##
  ## Returns the list of available environment variables in the current directory and
  ## the updated helpContent with the help for the commands related to the
  ## variables.
  require:
    db != nil
  body:
    # Add commands related to the shell's theme
    proc themeCommand(arguments: UserInput; db: DbConn;
        list: CommandLists): ResultCode {.raises: [], tags: [WriteIOEffect,
        WriteDbEffect, TimeEffect, ReadDbEffect, ReadIOEffect,
        RootEffect], ruleOff: "paramsUsed", contractual.} =
      ## The code of the shell's command "theme" and its subcommands
      ##
      ## * arguments - the arguments entered by the user for the command
      ## * db        - the connection to the shell's database
      ## * list      - the additional data for the command, like list of help
      ##               entries, etc
      ##
      ## Returns QuitSuccess if the selected command was successfully executed,
      ## otherwise QuitFailure.
      body:
        # No subcommand entered, show available options
        if arguments.len == 0:
          return showHelpList(command = "theme",
              subcommands = themeCommands, db = db)
        # Show the colors declared in the shell's theme
        if arguments.startsWith(prefix = "show"):
          return showTheme(db = db)
        # Set the new value for the selected theme's color
        if arguments.startsWith(prefix = "set"):
          return setColor(db = db, arguments = arguments)
        try:
          return showUnknownHelp(subCommand = arguments,
              command = initLimitedString(capacity = 5, text = "theme"),
              helpType = initLimitedString(capacity = 5, text = "theme"), db = db)
        except CapacityError:
          return QuitFailure.ResultCode

    try:
      addCommand(name = initLimitedString(capacity = 5, text = "theme"),
          command = themeCommand, commands = commands,
          subCommands = themeCommands)
    except CapacityError, CommandsListError:
      showThemeError(message = "Can't add commands related to the shell's theme. Reason: ",
          e = getCurrentException())
