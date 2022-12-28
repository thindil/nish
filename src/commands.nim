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
import std/[db_sqlite, os]
# External modules imports
import contracts
# Internal imports
import aliases, constants, directorypath, output, resultcode, variables

using
  db: DbConn # Connection to the shell's database
  aliases: ref AliasesList # The list of aliases available in the selected directory
  newDirectory: DirectoryPath # The directory to which the current directory will be changed

proc changeDirectory*(newDirectory; aliases; db): ResultCode {.gcsafe,
    sideEffect, raises: [], tags: [ReadEnvEffect, ReadIOEffect, ReadDbEffect,
        WriteIOEffect, ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Change the current directory for the shell
  ##
  ## * newDirectory - the path to the new directory to which the current
  ##                  working directory will be changed
  ## * aliases      - the list of available aliases in the current directory
  ## * db           - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the working directory was properly changed, otherwise
  ## QuitFailure. Also, updated parameter aliases.
  require:
    newDirectory.len > 0
    db != nil
  body:
    try:
      var path: DirectoryPath = try:
          absolutePath(path = expandTilde(path = $newDirectory)).DirectoryPath
        except ValueError:
          return showError(message = "Can't get absolute path to the new directory.")
      if not dirExists(dir = $path):
        return showError(message = "Directory '" & path & "' doesn't exist.")
      path = expandFilename(filename = $path).DirectoryPath
      setVariables(newDirectory = path, db = db, oldDirectory = getCurrentDir().DirectoryPath)
      setCurrentDir(newDir = $path)
      aliases.setAliases(directory = path, db = db)
      return QuitSuccess.ResultCode
    except OSError:
      return showError(message = "Can't change directory. Reason: ",
          e = getCurrentException())

proc cdCommand*(newDirectory; aliases; db): ResultCode {.gcsafe, sideEffect,
    raises: [], tags: [ReadEnvEffect, ReadIOEffect, ReadDbEffect, WriteIOEffect,
    WriteDbEffect, ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Build-in command to enter the selected by the user directory
  ##
  ## * newDirectory - the path to the new directory to which the current
  ##                  working directory will be changed
  ## * aliases      - the list of available aliases in the current directory
  ## * db           - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the working directory was properly changed, otherwise
  ## QuitFailure. Also, updated parameter aliases.
  require:
    db != nil
  body:
    if newDirectory.len == 0:
      result = changeDirectory(newDirectory = "~".DirectoryPath,
          aliases = aliases, db = db)
    else:
      result = changeDirectory(newDirectory = newDirectory, aliases = aliases, db = db)
