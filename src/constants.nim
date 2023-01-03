# Copyright © 2022-2023 Bartek Jasicki <thindil@laeran.pl>
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
import std/tables
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

type
  HelpEntry* = object
    ## Used to store the shell's help entries
    usage*: string ## The shell's command to enter for the selected entry
    content*: string ## The content of the selected entry
  UserInput* = LimitedString
    ## Used to store text entered by the user
  ExtendedNatural* = range[-1..high(int)]
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
