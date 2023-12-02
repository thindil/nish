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
import contracts, nimalyzer
import norm/[model, pragmas, sqlite]
# Internal imports
import logger, resultcode

type
  ColorName = enum
    ## Used to set the colors' value
    black, red, green, yellow, blue, magenta, cyan, white, default
  Color {.tableName: "theme".} = ref object of Model
    ## Data structure for the shell's color
    ##
    ## * name        - the name of the color in the shell's theme
    ## * cValue      - the name of the color, in 8 colors' terminal's pallete
    ## * description - the color's description, show to the user
    ## * bold        - if true, set the color with a bold font
    ## * underline   - if true, add underline to the color
    ## * italic      - if true, set the color with an italic font
    name {.unique.}: string
    cValue: ColorName
    description: string
    bold: bool
    underline: bool
    italic: bool

using db: DbConn # Connection to the shell's database

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

proc newColor*(name: string = ""; cValue: ColorName = default;
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

proc createThemeDb*(db): ResultCode {.sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Create the table theme
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
      var color: Color = newColor(name = "errors", cValue = red, description = "Used to show error messages")
      db.insert(obj = color)
    except:
      try:
        let e: ref Exception = getCurrentException()
        stderr.writeLine(x = "")
        {.ruleOff: "namedParams".}
        stderr.styledWrite(fgRed, "Can't create 'theme' table. Reason: ")
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
    return QuitSuccess.ResultCode

proc getColor*(db; name: string): Color {.contractual.} =
  require:
    name.len > 0
  body:
    result = newColor(cValue = red)
    if db == nil:
      return
    db.select(obj = result, "name=?", name)
