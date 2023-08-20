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

## This module contains DirectoryPath type, used to store paths to files and
## directories by the shell. It also provides some functions related to the
## type.

# Standard library imports
import std/strutils

type DirectoryPath* = distinct string
  ## Used to store paths to directories

proc `$`*(x: DirectoryPath): string {.borrow.}
  ## Get string representation of DirectoryPath. Borrowed from string type.
  ##
  ## * x - The DirectoryPath which will be converted to string
  ##
  ## Returns the string representation of x parameter

proc find*(s, sub: DirectoryPath; start: Natural = 0; last = 0): int {.borrow.}
  ## Find substring position in DirectoryPath. Borrowed from string type.
  ##
  ## * s     - The DirectoryPath which will be check for the selected character
  ## * sub   - The character which will be looked for in the DirectoryPath
  ## * start - The position from which search should start. Can be empty.
  ##           Default value is 0, start from the beginning of the DirectoryPath.
  ## * last  - The position to which search should go. Can be empty. Default
  ##           value is 0, which means no limit.
  ##
  ## Returns the position of the character in the DirectoryPath or -1 if character not
  ## found

proc len*(s: DirectoryPath): int {.borrow.}
  ## Get the length of DirectoryPath. Borrowed from int type.
  ##
  ## * s - The DirectoryPath which length will be count
  ##
  ## Returns the length of the selected DirectoryPath

proc `&`*(x: DirectoryPath; y: string): string {.borrow.}
  ## Concatenates DirectoryPath and string into one string. Borrowed from string
  ## type.
  ##
  ## * x - The DirectoryPath which will be concatenated
  ## * y - The string which will be concatenated
  ##
  ## Returns the merged DirectoryPath and string into one string

proc `&`*(x: string; y: DirectoryPath): string {.borrow.}
  ## Concatenates DirectoryPath and string into one string. Borrowed from string
  ## type.
  ##
  ## * x - The string which will be concatenated
  ## * y - The DirectoryPath which will be concatenated
  ##
  ## Returns the merged string and DirectoryPath into one string

func `!=`*(x: DirectoryPath; y: string): bool {.gcsafe, raises: [], tags: [], locks: 0.} =
  ## Compare the DirectoryPath and string
  ##
  ## * x - The DirectoryPath to compare
  ## * y - The string to compare
  ##
  ## Returns false if both DirectoryPath and string are the same, otherwise true
  return $x != y

func `==`*(x: DirectoryPath; y: string): bool {.gcsafe, raises: [], tags: [], locks: 0.} =
  ## Compare the DirectoryPath and string
  ##
  ## * x - The DirectoryPath to compare
  ## * y - The string to compare
  ##
  ## Returns true if both DirectoryPath and string are the same, otherwise false
  return $x == y
