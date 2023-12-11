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

## This module contains code related to the shell's colors' theme, like setting
## them, changing and getting from the database

# Standard library imports
import std/[strutils, terminal]
# External modules imports
import ansiparse, contracts, nancy, nimalyzer, termstyle
import norm/[model, pragmas, sqlite]
# Internal imports
import constants, logger, resultcode

type
  ColorName = enum
    ## Used to set the colors' value
    black, red, green, yellow, blue, magenta, cyan, white, default
  ThemeColor* = enum
    ## Used to set the colors' names
    errors, default, headers, tableHeaders, ids, values, showHeaders, success,
      helpUsage, helpCommand, helpReqParam, helpOptParam, helpUnderline,
      helpCode, highlightValid, highlightInvalid, highlightVariable,
      highlightText, suggestInvalid, suggestCommand, suggestYes, suggestNext,
      suggestAbort, promptColor, promptError
  Color {.tableName: "theme".} = ref object of Model
    ## Data structure for the shell's color
    ##
    ## * name        - the name of the color in the shell's theme
    ## * cValue      - the name of the color, in 8 colors' terminal's pallete
    ## * description - the color's description, show to the user
    ## * bold        - if true, set the color with a bold font
    ## * underline   - if true, add underline to the color
    ## * italic      - if true, set the color with an italic font
    name {.unique.}: ThemeColor
    cValue: ColorName
    description: string
    bold: bool
    underline: bool
    italic: bool

using db: DbConn # Connection to the shell's database

const themeCommands*: seq[string] = @["show"]
  ## The list of available subcommands for command theme

proc dbType*(T: typedesc[ColorName]): string {.raises: [], tags: [],
    contractual.} =
  ## Set the type of field in the database
  ##
  ## * T - the type for which the field will be set
  ##
  ## Returns the type of the field in the database
  body:
    "TEXT"

proc dbValue*(val: ColorName): DbValue {.raises: [], tags: [],
    contractual.} =
  ## Convert the type of the colors' value to database field
  ##
  ## * val - the value to convert
  ##
  ## Returns the converted val parameter
  body:
    dbValue(v = $val)

{.push ruleOff: "paramsUsed".}
proc to*(dbVal: DbValue, T: typedesc[ColorName]): T {.raises: [], tags: [],
    contractual.} =
  ## Convert the value from the database to enumeration
  ##
  ## * dbVal - the value to convert
  ## * T     - the type to which the value will be converted
  ##
  ## Returns the converted dbVal parameter
  body:
    try:
      parseEnum[ColorName](s = dbVal.s)
    except:
      default
{.pop ruleOff: "paramsUsed".}

proc dbType*(T: typedesc[ThemeColor]): string {.raises: [], tags: [],
    contractual.} =
  ## Set the type of field in the database
  ##
  ## * T - the type for which the field will be set
  ##
  ## Returns the type of the field in the database
  body:
    "TEXT"

proc dbValue*(val: ThemeColor): DbValue {.raises: [], tags: [],
    contractual.} =
  ## Convert the type of the colors' value to database field
  ##
  ## * val - the value to convert
  ##
  ## Returns the converted val parameter
  body:
    dbValue(v = $val)

{.push ruleOff: "paramsUsed".}
proc to*(dbVal: DbValue, T: typedesc[ThemeColor]): T {.raises: [], tags: [],
    contractual.} =
  ## Convert the value from the database to enumeration
  ##
  ## * dbVal - the value to convert
  ## * T     - the type to which the value will be converted
  ##
  ## Returns the converted dbVal parameter
  body:
    try:
      parseEnum[ThemeColor](s = dbVal.s)
    except:
      errors
{.pop ruleOff: "paramsUsed".}

proc newColor*(name: ThemeColor = errors; cValue: ColorName = default;
    description: string = ""; bold: bool = false; underline: bool = false;
    italic: bool = false): Color {.raises: [], tags: [], contractual.} =
  ## Create a new data structure for the shell's theme's color.
  ##
  ## * name        - the name of the color in the shell's theme
  ## * cValue      - the name of the color, in 8 colors' terminal's pallete
  ## * description - the color's description, show to the user
  ## * bold        - if true, set the color with a bold font
  ## * underline   - if true, add underline to the color
  ## * italic      - if true, set the color with an italic font
  ##
  ## Returns the new data structure for the selected shell's theme's color.
  body:
    Color(name: name, cValue: cValue, description: description, bold: bold,
        underline: underline, italic: italic)

let colors: array[25, Color] = [newColor(name = errors, cValue = red,
    description = "Used to show error messages"), newColor(name = default,
    cValue = default, description = "The default color of the shell's output"),
    newColor(name = headers, cValue = yellow,
    description = "Used to show headers of tables and forms"), newColor(
    name = tableHeaders, cValue = magenta,
    description = "Used to show tables headers"), newColor(name = ids,
    cValue = yellow, description = "Used to show indexes in tables"), newColor(
    name = values, cValue = green,
    description = "Used to show values in tables"), newColor(name = showHeaders,
    cValue = magenta,
    description = "Used in show subcommands for descriptions"), newColor(
    name = success, cValue = green,
    description = "Used to show success message of the shell's commands"),
    newColor(name = helpUsage, cValue = yellow,
    description = "Used to show command usage description in help entries"),
    newColor(name = helpCommand, cValue = green,
    description = "Used to show commands in help entries"), newColor(
    name = helpReqParam, cValue = cyan,
    description = "Used to show required parameters of commands in help entries"),
    newColor(name = helpOptParam, cValue = blue,
    description = "Used to show optional parameters of commands in help entries"),
    newColor(name = helpUnderline, cValue = yellow, underline = true,
    description = "Used to show underlined text help entries"), newColor(
    name = helpCode, cValue = green,
    description = "Used to show code in help entries"), newColor(
    name = highlightValid, cValue = green,
    description = "Used to highlight valid values in user's input"), newColor(
    name = highlightInvalid, cValue = red,
    description = "Used to highlight invalid values in user's input"), newColor(
    name = highlightVariable, cValue = cyan,
    description = "Used to highlight environment variables in user's input"),
    newColor(name = highlightText, cValue = yellow,
    description = "Used to highlight text in quotes in user's input"), newColor(
    name = suggestInvalid, cValue = cyan,
    description = "Used to show invalid command in commands' suggestions"),
    newColor(name = suggestCommand, cValue = yellow,
    description = "Used to show command suggestion in commands' suggestions"),
    newColor(name = suggestYes, cValue = green,
    description = "Used to show confirmation shortcut in commands' suggestions"),
    newColor(name = suggestNext, cValue = blue,
    description = "Used to show next shortcut in commands' suggestions"),
    newColor(name = suggestAbort, cValue = red,
    description = "Used to show abort shortcut in commands' suggestions"),
    newColor(name = promptColor, cValue = blue,
    description = "Used to show the shell's prompt"), newColor(
    name = promptError, cValue = red,
    description = "Used to show the last command's error code in the shell's prompt")]
      ## The list of available the shell's theme's colors

proc showThemeError*(message: string; e: ref Exception) {.sideEffect, raises: [
    ], tags: [WriteIOEffect, RootEffect], contractual.} =
  ## Show the information about the error related to the theme. The theme's
  ## module uses the separated code, to avoid circular dependencies and eternal
  ## errors.
  ##
  ## * message - the message to show to the user
  ## * e       - the exception which happened
  require:
    message.len > 0
    e != nil
  body:
    try:
      stderr.writeLine(x = "")
      {.ruleOff: "namedParams".}
      stderr.styledWrite(fgRed, message)
      stderr.styledWriteLine(fgRed, $e.name)
      logToFile(message = $e.name)
      stderr.styledWriteLine(fgRed, getCurrentExceptionMsg())
      logToFile(message = getCurrentExceptionMsg())
      when defined(debug):
        stderr.styledWrite(fgRed, e.getStackTrace)
        logToFile(message = e.getStackTrace)
      {.ruleOn: "namedParams".}
    except:
      discard

proc createThemeDb*(db): ResultCode {.sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Create the table theme and insert the default colors settings
  ##
  ## * db - the connection to the shell's database
  ##
  ## Returns QuitSuccess if creation was successfull, otherwise QuitFailure and
  ## show message what wrong
  require:
    db != nil
  body:
    try:
      db.createTables(obj = newColor())
      for color in colors:
        var col = color
        db.insert(obj = col)
    except:
      showThemeError(message = "Can't create 'theme' table. Reason: ",
          e = getCurrentException())
      return QuitFailure.ResultCode
    return QuitSuccess.ResultCode

proc getColor*(db; name: ThemeColor): string {.sideEffect, raises: [], tags: [
    ReadDbEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Get the selected the shell's theme's color.
  ##
  ## * db   - the connection to the shell's database
  ## * name - the name of the color to get
  ##
  ## Returns the terminal code related to the selected theme's color
  body:
    var color: Color = newColor(cValue = red)
    if db == nil:
      return termRed
    try:
      db.select(obj = color, cond = "name=?", params = $name)
    except:
      showThemeError(message = "Can't get the shell's theme color: '" & $name &
          "'. Reason: ", e = getCurrentException())
    case color.cValue
    of black:
      result = termBlack
    of red:
      result = termRed
    of green:
      result = termGreen
    of yellow:
      result = termYellow
    of blue:
      result = termBlue
    of magenta:
      result = termMagenta
    of cyan:
      result = termCyan
    of white:
      result = termWhite
    of default:
      result = termClear
    if color.bold:
      result &= termBold
    if color.underline:
      result &= termUnderline
    if color.italic:
      result &= termItalic

proc showThemeFormHeader(message: string; width: ColumnAmount = (
    try: terminalWidth().ColumnAmount except ValueError: 80.ColumnAmount);
        db) {.sideEffect, raises: [], tags: [ReadIOEffect, WriteIOEffect,
    RootEffect], contractual.} =
  ## Show form's header with the selected message.  The theme's
  ## module uses the separated code, to avoid circular dependencies and eternal
  ## errors.
  ##
  ## * message - the text which will be shown in the header
  ## * width   - the width of the header. Default value is the current width
  ##             of the terminal
  ## * db      - the connection to the shell's database
  require:
    message.len > 0
    db != nil
  body:
    type LocalOption = ref object
      value: string
    try:
      var option: LocalOption = LocalOption()
      db.rawSelect(qry = "SELECT value FROM options WHERE option='outputHeaders'", obj = option)
      let headerType: string = option.value
      if headerType == "hidden":
        return
      var table: TerminalTable = TerminalTable()
      table.add(parts = style(ss = message.center(width = width.int),
          style = getColor(db = db, name = headers)))
      case headerType
      of "unicode":
        table.echoTableSeps(seps = boxSeps)
      of "ascii":
        table.echoTableSeps
      of "none":
        table.echoTable
      else:
        discard
    except DbError, IOError, Exception:
      showThemeError(message = "Can't show theme's form header. Reason: ",
          e = getCurrentException())

proc showTheme*(db): ResultCode {.sideEffect, raises: [], tags: [
    WriteIOEffect, ReadIOEffect, ExecIOEffect, RootEffect], contractual.} =
  ## Show all the colors which can be set in the shell's theme
  ##
  ## * db        - the connection to the shell's database
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
      showThemeError(message = "Can't show the shell's theme's colors. Reason: ",
          e = getCurrentException())
      return QuitFailure.ResultCode
    showThemeFormHeader(message = "The shell's theme colors are:", db = db)
    try:
      var colors: seq[Color] = @[newColor()]
      db.rawSelect(qry = "SELECT * FROM theme ORDER BY name ASC",
          objs = colors)
      for color in colors:
        table.add(parts = [style(ss = color.name, style = getColor(db = db,
            name = ids)), style(ss = color.cValue, style = getColor(db = db,
            name = values)), color.description])
    except:
      showThemeError(message = "Can't show the shell's theme's colors. Reason: ",
          e = getCurrentException())
      return QuitFailure.ResultCode
    try:
      table.echoTable
    except IOError, Exception:
      showThemeError(message = "Can't show the list of shell's theme's colors. Reason: ",
          e = getCurrentException())
      return QuitFailure.ResultCode
    return QuitSuccess.ResultCode
