# Copyright © 2022-2024 Bartek Jasicki
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

## This module contains constants used by the shell's code

# Standard library imports
import std/[dirs, os, paths]
# External modules imports
import contracts

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

proc getCurrentDirectory*(): Path {.raises: [], tags: [ReadIOEffect],
    contractual.} =
  ## Get the current directory. Exception free version of getCurrentDir
  ##
  ## Returns the current directory path. If it doesn't exist, for example was
  ## deleted by other program, returns the home directory of the user.
  body:
    try:
      result = paths.getCurrentDir()
    except OSError:
      result = getHomeDir().Path
      try:
        setCurrentDir(newDir = result)
      except OSError:
        try:
          result = getAppDir().Path
          setCurrentDir(newDir = result)
        except OSError:
          discard
