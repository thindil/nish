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

## This module contains code related to the completion with Tab key the user's
## input, like completing names of files, directories, commands, etc.

# Standard library imports
import std/[os, strutils, tables]
# External modules imports
import contracts
import norm/sqlite
# Internal imports
import commandslist, constants, lstring, options, output

using db: DbConn # Connection to the shell's database

proc getDirCompletion*(prefix: string; completions: var seq[string];
    db) {.gcsafe, sideEffect, raises: [], tags: [ReadDirEffect, WriteIOEffect,
    ReadDbEffect, ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Get the relative path of file or directory, based on the selected prefix
  ## in the current directory.
  ##
  ## * prefix      - the prefix which will be looking for in the current directory
  ## * completions - the list of completions for the current prefix
  ##
  ## Returns the updated completions parameter with additional entries of relative
  ## paths to the files or directories which match the parameter prefix. If
  ## prefix is empty, or there is no matching file or directory, returns the
  ## same completion parameter.
  body:
    if prefix.len == 0:
      return
    let completionAmount: int = try:
        parseInt(s = $getOption(optionName = initLimitedString(
          capacity = 16, text = "completionAmount"), db = db,
          defaultValue = initLimitedString(capacity = 2, text = "30")))
      except ValueError, CapacityError:
        30
    # Completion disabled
    if completionAmount == 0:
      return
    let caseSensitive: bool = try:
        parseBool(s = $getOption(optionName = initLimitedString(
          capacity = 19, text = "completionCheckCase"), db = db,
          defaultValue = initLimitedString(capacity = 5, text = "false")))
      except ValueError, CapacityError:
        true
    try:
      if caseSensitive:
        for item in walkPattern(pattern = prefix & "*"):
          if completions.len >= completionAmount:
            return
          let completion: string = (if dirExists(dir = item): item &
              DirSep else: item)
          if completion notin completions:
            completions.add(y = completion)
      else:
        let
          parentDir: string = (if prefix.parentDir ==
              ".": "" else: prefix.parentDir & DirSep)
          prefixInsensitive: string = prefix.lastPathPart.toLowerAscii
        echo "\nprefix: ", prefix, " dir:", getCurrentDirectory() & DirSep & parentDir
        for item in walkDir(dir = getCurrentDirectory() & DirSep & parentDir,
            relative = true):
          if completions.len >= completionAmount:
            return
          var completion: string = (if dirExists(dir = item.path): item.path &
              DirSep else: item.path)
          if (completion.toLowerAscii.startsWith(prefix = prefixInsensitive) or
              prefix.endsWith(suffix = DirSep)) and completion notin completions:
            completions.add(y = parentDir & completion)
    except OSError, ValueError:
      showError(message = "Can't get completion. Reason: ",
          e = getCurrentException())

proc getCommandCompletion*(prefix: string; completions: var seq[string];
    aliases: ref AliasesList; commands: ref CommandsList; db) {.gcsafe,
    sideEffect, raises: [], tags: [ReadEnvEffect, ReadDirEffect, ReadDbEffect,
    ReadEnvEffect, TimeEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Get the list of available commands which starts with the selected prefix
  ##
  ## * prefix      - the prefix which will be looking for in commands
  ## * completions - the list of completions for the current prefix
  ## * aliases     - the list of available shell's aliases
  ## * commands    - the list of the shell's commands
  ##
  ## Returns the updated completions parameter with additional entries of commands
  ## which match the parameter prefix. If prefix is empty, or there is no
  ## matching file or directory, returns unchanged completion parameter.
  body:
    if prefix.len == 0:
      return
    let completionAmount: int = try:
        parseInt(s = $getOption(optionName = initLimitedString(
          capacity = 16, text = "completionAmount"), db = db,
          defaultValue = initLimitedString(capacity = 2, text = "30")))
      except ValueError, CapacityError:
        30
    # Completion disabled
    if completionAmount == 0:
      return
    # Check built-in commands
    for command in builtinCommands:
      if completions.len >= completionAmount:
        return
      if command.startsWith(prefix = prefix) and command notin completions:
        completions.add(y = command)
    # Check for all shell's commands
    for command in commands.keys:
      if completions.len >= completionAmount:
        return
      if command.startsWith(prefix = prefix) and command notin completions:
        completions.add(y = command)
    # Check the shell's aliases
    for alias in aliases.keys:
      if completions.len >= completionAmount:
        return
      if alias.startsWith(prefix = prefix) and $alias notin completions:
        completions.add(y = $alias)
    try:
      for path in getEnv(key = "PATH").split(sep = PathSep):
        for file in walkFiles(pattern = path & DirSep & prefix & "*"):
          if completions.len >= completionAmount:
            return
          let fileName: string = file.extractFilename
          if fileName notin completions:
            completions.add(y = fileName)
    except OSError:
      return

