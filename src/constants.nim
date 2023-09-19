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

## This module contains constants and variables types used by the shell's code

# Standard library imports
import std/[os, tables]
# External modules imports
import contracts, nimalyzer
import norm/sqlite
# Internal imports
import lstring

const
  maxNameLength*: Positive = 50
    ## Max allowed length of various names (options, variables, etc). Can be
    ## customized separately for each name's type either in the proper modules.
  aliasNameLength*: Positive = maxNameLength
    ## The maximum length of the shell's alias namev
  builtinCommands*: array[0..3, string] = ["cd", "exit", "set", "unset"]
    ## The list of the shell's built-in commands
  maxInputLength*: Positive = 4096
    ## The maximum length of the user input

type
  HelpEntry* = object
    ## Used to store the shell's help entries
    usage*: string   ## The shell's command to enter for the selected entry
    content*: string ## The content of the selected entry
  UserInput* = LimitedString
    ## Used to store text entered by the user
  ExtendedNatural* = range[-1..int.high]
    ## Used to store various indexes
  BooleanInt* = range[0..1]
    ## Used to store boolean values in database
  HistorySort* = enum
    ## Used to set the sort type for showing the last commands in the shell's
    ## history
    recent, amount, name, recentamount
  AliasName* = LimitedString
    ## Used to store aliases names in tables and database.
  AliasesList* = OrderedTable[AliasName, int]
    ## Used to store the available aliases in the selected directory
  ColumnAmount* = distinct Natural
    ## Used to store length or amount of terminal's characters columns

proc getCurrentDirectory*(): string {.raises: [], tags: [ReadIOEffect],
    contractual.} =
  ## Get the current directory. Exception free version of getCurrentDir
  ##
  ## Returns the current directory path. If it doesn't exist, for example was
  ## deleted by other program, returns the home directory of the user.
  body:
    try:
      result = getCurrentDir()
    except OSError:
      result = getHomeDir()
      try:
        setCurrentDir(newDir = result)
      except OSError:
        try:
          result = getAppDir()
          setCurrentDir(newDir = result)
        except OSError:
          discard

{.push ruleOff: "paramsUsed".}
proc dbType*(T: typedesc[LimitedString]): string {.raises: [], tags: [],
    contractual.} =
  ## Get the type of database's field for LimitedString fields
  ##
  ## * T - the type of the object field for which the database type will be get
  ##
  ## Returns string with the type of the database's field for the selected type.
  body:
    return "TEXT"
{.pop ruleOff: "paramsUsed".}

proc dbValue*(val: LimitedString): DbValue {.raises: [], tags: [],
    contractual.} =
  ## Get the value of LimitedString for the database
  ##
  ## * val - the value which will be converted to the database's value
  ##
  ## Returns the database value of the LimitedString variable
  body:
    return dbValue(v = $val)

proc to*(dbVal: DbValue, T: typedesc[LimitedString]): T {.raises: [], tags: [],
    contractual.} =
  ## Convert the database's value to LimitedString value
  ##
  ## * dbVal - the value which will be converted to LimitedString
  ## * T     - the type to which the value will be converted
  ##
  ## Returns LimitedString with the value from the database
  body:
    try:
      return initLimitedString(capacity = dbVal.s.len, text = dbVal.s)
    except CapacityError:
      return emptyLimitedString()

