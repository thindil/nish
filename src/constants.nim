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

import std/[strutils, tables]
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
  DirectoryPath* = distinct string # Used to store paths to directories
  UserInput* = LimitedString # Used to store text entered by the user
  DatabaseId* = distinct Natural # Used to store ids from or to the shell's database
  ExtendedNatural* = range[-1..high(int)] # Used to store various indexes
  BooleanInt* = range[0..1] # Used to store boolean values in database

# Subprograms related to DatabaseId type
proc `$`*(x: DatabaseId): string {.borrow.} # Get string representation of ResultCode

# Subprograms related to DirectoryPath type
proc `$`*(x: DirectoryPath): string {.borrow.} # Get string representation of DirectoryPath
proc find*(s, sub: DirectoryPath; start: Natural = 0;
    last = 0): int {.borrow.} # Find substring position in DirectoryPath
proc len*(s: DirectoryPath): int {.borrow.} # Get the length of DirectoryPath
proc `&`*(x: DirectoryPath; y: string): string {.borrow.} # Concatenates DirectoryPath and string into one string
proc `&`*(x: string; y: DirectoryPath): string {.borrow.} # Concatenates string and DirectoryPath into one string
func `!=`*(x: DirectoryPath; y: string): bool {.gcsafe, raises: [], tags: [],
    locks: 0.} = # Compare the DirectoryPath and string
  return $x != y
func `==`*(x: DirectoryPath; y: string): bool {.gcsafe, raises: [], tags: [],
    locks: 0.} = # Compare the DirectoryPath and string
  return $x == y
