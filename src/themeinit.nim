# Copyright © 2023-2024 Bartek Jasicki
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
import commandslist, constants, help, input, output, resultcode, theme

using db: DbConn # Connection to the shell's database

proc showTheme(db): ResultCode {.sideEffect, raises: [], tags: [
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

proc editTheme(db): ResultCode {.sideEffect, raises: [], tags: [
    WriteIOEffect, ReadIOEffect, ExecIOEffect, RootEffect], contractual.} =
  ## Set the value for the theme's color
  ##
  ## * db - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the color was properly set, otherwise QuitFailure.
  require:
    db != nil
  body:
    # Select the color to edit
    showOutput(message = "You can cancel editing a color at any time by double press Escape key or enter word 'exit' as an answer.", db = db)
    showFormHeader(message = "(1/5) Name:", db = db)
    showOutput(message = "You can get more information about each color with command ", db= db, newLine = false)
    showOutput(message = "'theme list'", color = helpCommand, db = db, newLine = false)
    showOutput(message = ".", db = db)
    var color: Color = newColor()
    askForName[Color](db = db, action = "Editing the theme",
        namesType = "color", name = color)
    if color.description.len == 0:
      return QuitFailure.ResultCode
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

proc resetTheme(arguments: UserInput; db): ResultCode {.sideEffect, raises: [],
    tags: [ReadIOEffect, WriteIOEffect, WriteDbEffect, ReadDbEffect, TimeEffect,
    RootEffect], contractual.} =
  ## Reset the selected theme's color's values to default values. If the optional
  ## parameter "all" is set, reset all colors to their default values
  ##
  ## * arguments - the user entered text with arguments for the command, empty or
  ##               "all"
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the theme was correctly reseted, otherwise QuitFailure.
  require:
    arguments.len > 0
    db != nil
  body:
    var resetAll: bool = false
    if arguments.len > 7 and arguments[6 .. ^1] == "all":
      resetAll = true
    # Reset the whole theme
    if resetAll:
      try:
        var cols: seq[Color] = @[newColor()]
        db.selectAll(objs = cols)
        for color in colors:
          for index, col in cols.mpairs:
            if col.name == color.name:
              cols[index].cValue = color.cValue
              cols[index].bold = color.bold
              cols[index].underline = color.underline
              cols[index].italic = color.italic
              break
        db.update(objs = cols)
      except:
        return showError(message = "Can't reset the whole theme. Reason: ",
            e = getCurrentException(), db = db)
      showOutput(message = "The shell's theme reseted to its default values.",
          color = success, db = db)
    # Reset the selected color
    else:
      var color: Color = newColor()
      askForName[Color](db = db, action = "Reseting the color",
          namesType = "color", name = color)
      if color.description.len == 0:
        return QuitFailure.ResultCode
      for col in colors:
        if col.name == color.name:
          color.cValue = col.cValue
          color.bold = col.bold
          color.underline = col.underline
          color.italic = col.italic
          break
      try:
        db.update(obj = color)
      except:
        return showError(message = "Can't update the shell's theme's color. Reason: ",
            e = getCurrentException(), db = db)
      showOutput(message = "The shell's theme color '" & $color.name &
          "' reseted to its default value.", color = success, db = db)
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
        if arguments.startsWith(prefix = "list"):
          return showTheme(db = db)
        # Set the new values for the theme's colors
        if arguments.startsWith(prefix = "edit"):
          return editTheme(db = db)
        # Reset the theme's colors to their default values (all colors or one)
        if arguments.startsWith(prefix = "reset"):
          return resetTheme(arguments = arguments, db = db)
        return showUnknownHelp(subCommand = arguments,
            command = "theme",
            helpType = "theme", db = db)

    try:
      addCommand(name = "theme",
          command = themeCommand, commands = commands,
          subCommands = themeCommands)
    except CommandsListError:
      showThemeError(message = "Can't add commands related to the shell's theme. Reason: ",
          e = getCurrentException())
