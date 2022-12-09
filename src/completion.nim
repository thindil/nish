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

# Standard library imports
import std/[db_sqlite, os, strutils, tables]
# External modules imports
import contracts
# Internal imports
import commandslist, constants, lstring, options, output

using db: DbConn # Connection to the shell's database

proc addCompletion*(list: var seq[string]; item: string; amount: var Positive;
    db): bool {.gcsafe, sideEffect, raises: [], tags: [ReadDbEffect,
    WriteIOEffect, ReadEnvEffect, TimeEffect], contractual.} =
  ## FUNCTION
  ##
  ## Add the selected item to the completions list if there is no that item
  ## in the list.
  ##
  ## PARAMETERS
  ##
  ## * list   - the list of completions to which the item will be added
  ## * item   - the item to add to the list
  ## * amount - the overall amount of added items to the list
  ##
  ## RETURNS
  ##
  ## True if the overall amount of added items reached limit, otherwise false.
  ## Also, if item was added, it returns the modified parameters list and
  ## amount. If item was not added, it returns not modified parameters list
  ## and amount.
  require:
    item.len > 0
  body:
    if item notin list:
      list.add(y = item)
      amount.inc
    try:
      if amount > parseInt(s = $getOption(optionName = initLimitedString(
          capacity = 16, text = "completionAmount"), db = db,
          defaultValue = initLimitedString(capacity = 2, text = "30"))):
        return true
    except ValueError, CapacityError:
      showError(message = "Can't get the amount of completions to show. Reason: ",
          e = getCurrentException())
      return true
    return false

proc getDirCompletion*(prefix: string; completions: var seq[string];
    db) {.gcsafe, sideEffect, raises: [], tags: [ReadDirEffect, WriteIOEffect,
    ReadDbEffect, ReadEnvEffect, TimeEffect], contractual.} =
  ## FUNCTION
  ##
  ## Get the relative path of file or directory, based on the selected prefix
  ## in the current directory.
  ##
  ## PARAMETERS
  ##
  ## * prefix      - the prefix which will be looking for in the current directory
  ## * completions - the list of completions for the current prefix
  ##
  ## RETURNS
  ##
  ## The updated completions parameter with additional entries of relative
  ## paths to the files or directories which match the parameter prefix. If
  ## prefix is empty, or there is no matching file or directory, returns the
  ## same completion parameter.
  body:
    if prefix.len == 0:
      return
    try:
      var amount: Positive = 1
      for item in walkPattern(pattern = prefix & "*"):
        let completion = (if dirExists(dir = item): item & DirSep else: item)
        if addCompletion(list = completions, item = completion, amount = amount, db = db):
          return
    except OSError:
      showError(message = "Can't get completion. Reason: ",
          e = getCurrentException())

proc getCommandCompletion*(prefix: string; completions: var seq[string];
    aliases: ref AliasesList; commands: ref CommandsList; db) {.gcsafe,
    sideEffect, raises: [], tags: [ReadEnvEffect, ReadDirEffect, ReadDbEffect,
    ReadEnvEffect, TimeEffect, WriteIOEffect], contractual.} =
  ## FUNCTION
  ##
  ## Get the list of available commands which starts with the selected prefix
  ##
  ## PARAMETERS
  ##
  ## * prefix      - the prefix which will be looking for in commands
  ## * completions - the list of completions for the current prefix
  ## * aliases     - the list of available shell's aliases
  ## * commands    - the list of the shell's commands
  ##
  ## RETURNS
  ##
  ## The updated completions parameter with additional entries of commands
  ## which match the parameter prefix. If prefix is empty, or there is no
  ## matching file or directory, returns unchanged completion parameter.
  body:
    if prefix.len == 0:
      return
    var amount: Positive = 1
    # Check built-in commands
    for command in builtinCommands:
      if command.startsWith(prefix = prefix):
        if addCompletion(list = completions, item = command, amount = amount, db = db):
          return
    # Check for all shell's commands
    for command in commands.keys:
      if command.startsWith(prefix = prefix):
        if addCompletion(list = completions, item = command, amount = amount, db = db):
          return
    # Check the shell's aliases
    for alias in aliases.keys:
      if alias.startsWith(prefix = prefix):
        if addCompletion(list = completions, item = $alias, amount = amount, db = db):
          return
    for path in getEnv(key = "PATH").split(sep = PathSep):
      for file in walkFiles(pattern = path & DirSep & prefix & "*"):
        if addCompletion(list = completions, item = file.extractFilename,
            amount = amount, db = db):
          return

