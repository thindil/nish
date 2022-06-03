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

import std/tables
import lstring

# Max allowed length of various names (options, variables, etc). Can be
# customized separately for each name's type either in the proper modules.
const maxNameLength*: Positive = 50

type
  HelpEntry* = object
    # Used to store the shell's help entries
    usage*: string   # The shell's command to enter for the selected entry
    content*: string # The content of the selected entry
  HelpTable* = Table[string, HelpEntry] # Used to store the shell's help content
  DirectoryPath* = string # Used to store paths to directories
  UserInput* = LimitedString # Used to store text entered by the user
  ResultCode* = distinct Natural # Used to store result code from commands entered by the user
  ColumnAmount* = distinct Natural # Used to store length or amount of terminal's characters columns
  DatabaseId* = Natural # Used to store ids from or to the shell's database
  ExtendedNatural* = range[-1..high(int)] # Used to store various indexes
  BooleanInt* = range[0..1] # Used to store boolean values in database


# Subprograms related to ResultCode type
proc `==`*(x: ResultCode; y: int): bool {.borrow.} # Used to compare ResultCode with int
proc `$`*(x: ResultCode): string {.borrow.} # Get string representation of ResultCode

# Subprograms related to ColumnAmount type
proc `/`*(x: ColumnAmount; y: int): ColumnAmount =
  # Used to divide ColumnAmount by integer
  return ColumnAmount(int(x) / y)
proc `-`*(x: ColumnAmount; y: int): int {.borrow.} # Used to substraction int from ColumnAmount
proc `*`*(x: ColumnAmount; y: int): int {.borrow.} # Uset to multiply ColumnAmount by int

