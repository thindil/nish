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

## This module contains initialization code and the commands related to the
## shell's theme. It is in a separate module to avoid circular dependencies and
## possibility to use the theme's colors in its commands.

# Standard library imports
import std/[strutils, tables]
# External modules imports
import ansiparse, contracts, nancy, nimalyzer, termstyle
import norm/sqlite
# Internal imports
import commandslist, constants, help, input, lstring, output, resultcode, theme

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
      return showError(message = "Can't show the shell's theme's colors. Reason: ",
          e = getCurrentException(), db = db)
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
      return showError(message = "Can't show the shell's theme's colors. Reason: ",
          e = getCurrentException(), db = db)
    try:
      table.echoTable
    except:
      return showError(message = "Can't show the list of shell's theme's colors. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc editTheme*(db): ResultCode {.sideEffect, raises: [], tags: [
    WriteIOEffect, ReadIOEffect, ExecIOEffect, RootEffect], contractual.} =
  ## Set the value for the theme's color
  ##
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the color was properly set, otherwise QuitFailure.
  require:
    db != nil
  body:
    # Select the color to edit
    showOutput(message = "You can cancel editing a color at any time by double press Escape key or enter word 'exit' as an answer.", db = db)
    showFormHeader(message = "(1/5) Name:", db = db)
    showOutput(message = "The name of the color. Select its Id from the list.", db = db)
    var
      table: TerminalTable = TerminalTable()
      cols: seq[Color] = @[newColor()]
    try:
      db.rawSelect(qry = "SELECT * FROM theme ORDER BY name ASC",
          objs = cols)
      var
        rowIndex: Natural = 0
        row: array[4, string] = ["", "", "", ""]
      for index, color in cols:
        row[rowIndex] = style(ss = "[" & $(index + 1) & "] ", style = getColor(
            db = db, name = ids)) & style(ss = color.name, style = getColor(
            db = db,
            name = values))
        rowIndex.inc
        if rowIndex == 4:
          table.add(parts = row)
          row = ["", "", "", ""]
          rowIndex = 0
      table.add(parts = row)
    except:
      return showError(message = "Can't show the shell's theme's colors. Reason: ",
          e = getCurrentException(), db = db)
    try:
      table.echoTable
    except:
      return showError(message = "Can't show the list of shell's theme's colors. Reason: ",
          e = getCurrentException(), db = db)
    showOutput(message = "Color number: ", newLine = false, db = db)
    let id: UserInput = readInput(db = db)
    if id == "exit":
      return showError(message = "Editing the theme cancelled.", db = db)
    var color: Color = try:
        cols[parseInt(s = $id) - 1]
      except:
        return showError(message = "Editing the theme cancelled, invalid color number: '" &
            id & "'", db = db)
    showOutput(message = "Current values for the color ", db = db,
        newLine = false)
    showOutput(message = $color.name, db = db, newLine = false, color = ids)
    showOutput(message = " " & color.description.toLowerAscii & " is: ",
        db = db, newLine = false)
    var value: string = $color.cValue
    if color.underline:
      value &= ", underlined"
    if color.bold:
      value &= ", bold"
    if color.italic:
      value &= ", italic"
    showOutput(message = value, db = db, color = values)
    # Select the new color value for the selected color
    showFormHeader(message = "(2/5) Color:", db = db)
    showOutput(message = "The name of the color used for the selected theme color.", db = db)
    const colorsOptions: Table[char, string] = {'b': "black", 'r': "red",
        'g': "green", 'y': "yellow", 'l': "blue", 'm': "magenta", 'c': "cyan",
        'w': "white", 'd': "default color", 'q': "quit"}.toTable
    var inputChar: char = selectOption(options = colorsOptions, default = 'd',
        prompt = "Color", db = db)
    try:
      case inputChar
      of 'b':
        color.cValue = black
      of 'r':
        color.cValue = red
      of 'g':
        color.cValue = green
      of 'y':
        color.cValue = yellow
      of 'l':
        color.cValue = blue
      of 'm':
        color.cValue = magenta
      of 'c':
        color.cValue = cyan
      of 'w':
        color.cValue = white
      of 'd':
        color.cValue = default
      of 'q':
        return showError(message = "Editing the theme cancelled.", db = db)
      else:
        discard
    except CapacityError:
      return showError(message = "Editing the theme cancelled. Reason: Can't set color value for the selected theme's color", db = db)
    # Select bold state of the selected color
    showFormHeader(message = "(3/5) Bold:", db = db)
    showOutput(message = "Select the color should be in bold font or not. Not all terminal emulators support the option.", db = db)
    color.bold = confirm(prompt = "Bold", db = db)
    # Select underline state of the selected color
    showFormHeader(message = "(4/5) Underlined:", db = db)
    showOutput(message = "Select the color should have underline or not. Not all terminal emulators support the option.", db = db)
    color.underline = confirm(prompt = "Underlined", db = db)
    # Select italic state of the selected color
    showFormHeader(message = "(5/5) Italic:", db = db)
    showOutput(message = "Select the color should be in italic for or not. Not all terminal emulators support the option.", db = db)
    color.italic = confirm(prompt = "Italic", db = db)
    # Save the color to the database
    try:
      db.update(obj = color)
    except:
      return showError(message = "Can't save the edits of the theme to database. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc initTheme*(db: DbConn; commands: ref CommandsList) {.sideEffect, raises: [
    ], tags: [ReadDbEffect, WriteIOEffect, TimeEffect, WriteDbEffect,
        RootEffect],
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
        # Set the new values for the theme's colors
        if arguments.startsWith(prefix = "edit"):
          return editTheme(db = db)
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
