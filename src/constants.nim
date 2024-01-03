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
import contracts
import norm/[model, pragmas]
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
  version*: string = "0.7.0"
    ## The version of the shell

type
  HelpEntry* {.tableName: "help".} = ref object of Model
    ## Data structure for the help's entries
    ##
    ## * topic    - the help's entry topic, show on the list of help's entries
    ## * usage    - the usage section of the help's entry
    ## * content  - the content of the help's entry
    ## * plugin   - the name of the plugin to which the help's entry belongs.
    ## * template - if true, the entry is a template and treated differently. It
    ##              have some variables in own content which will be replaced by
    ##              proper values when show to the user.
    topic* {.unique.}: string
    usage*: string
    content*: string
    plugin*: string
    `template`*: bool
  OptionValType* = enum
    ## Used to set the type of option's value
    integer, float, boolean, none, historysort, natural, text, command, header, positive
  Option* {.tableName: "options".} = ref object of Model
    ## Data structure for the shell's option
    ##
    ## * option       - the name of the option
    ## * value        - the value of the option
    ## * description  - the description of the option
    ## * valueType    - the type of the option's value
    ## * defaultValue - the default value for the option
    ## * readOnly     - if true, the option can be only read by the user, not set
    option*: string
    value*: string
    description*: string
    valueType*: OptionValType
    defaultValue*: string
    readOnly*: bool
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
  Alias* {.tableName: "aliases".} = ref object of Model
    ## Data structure for the shell's alias
    ##
    ## * name        - the name of the alias, used to trigger it
    ## * path        - the path in which the alias will work
    ## * recursive   - if true, the alias will be available also in subdirectories
    ## * commmands   - the commands to execute by the alias
    ## * description - the description of the alias, showed on the list of aliases
    ##                 or in the alias information
    ## * output      - where to redirect the output of the alias' commands
    name* {.unique.}: string
    path*: string
    recursive*: bool
    commands*: string
    description*: string
    output*: string
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
