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

import std/[db_sqlite, os, tables]
import contracts
import aliases, constants, directorypath, lstring, output, resultcode, variables

type
  CommandProc* = proc (arguments: UserInput; db: DbConn): ResultCode {.gcsafe.}
  ## FUNCTION
  ##
  ## The shell's command's code
  CommandsList = Table[string, CommandProc]
  ## FUNCTION
  ##
  ## Used to store the shell's commands

using
  db: DbConn # Connection to the shell's database
  aliases: var AliasesList # The list of aliases available in the selected directory
  newDirectory: DirectoryPath # The directory to which the current directory will be changed

proc changeDirectory*(newDirectory; aliases; db): ResultCode {.gcsafe,
    sideEffect, raises: [], tags: [ReadEnvEffect, ReadIOEffect, ReadDbEffect,
        WriteIOEffect, ReadEnvEffect, TimeEffect], contractual.} =
  ## FUNCTION
  ##
  ## Change the current directory for the shell
  ##
  ## PARAMETERS
  ##
  ## * newDirectory - the path to the new directory to which the current
  ##                  working directory will be changed
  ## * aliases      - the list of available aliases in the current directory
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the working directory was properly changed, otherwise
  ## QuitFailure. Also, updated parameter aliases.
  require:
    newDirectory.len() > 0
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
    WriteDbEffect, ReadEnvEffect, TimeEffect], contractual.} =
  ## FUNCTION
  ##
  ## Build-in command to enter the selected by the user directory
  ##
  ## PARAMETERS
  ##
  ## * newDirectory - the path to the new directory to which the current
  ##                  working directory will be changed
  ## * aliases      - the list of available aliases in the current directory
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the working directory was properly changed, otherwise
  ## QuitFailure. Also, updated parameter aliases.
  require:
    db != nil
  body:
    if newDirectory.len() == 0:
      result = changeDirectory(newDirectory = "~".DirectoryPath,
          aliases = aliases, db = db)
    else:
      result = changeDirectory(newDirectory = newDirectory, aliases = aliases, db = db)

func initCommands*(helpContent: var HelpTable) {.gcsafe, locks: 0, raises: [],
    tags: [].} =
  ## FUNCTION
  ##
  ## Initialize the shell's build-in commands. At this moment only set help
  ## related to the commands
  ##
  ## PARAMETERS
  ##
  ## * helpContent - the HelpTable with help content of the shell
  ##
  ## RETURNS
  ##
  ## The updated helpContent with the help for the commands related to the
  ## shell's build-in commands.
  helpContent["cd"] = HelpEntry(usage: "cd ?directory?",
      content: "You must have permissions to enter the directory and directory need to exists. If you enter just 'cd' without the name of the directory to enter, the current directory will be switched to your home directory.")
  helpContent["exit"] = HelpEntry(usage: "exit",
      content: "Exit from the shell.")
  helpContent["help"] = HelpEntry(usage: "help ?command?",
      content: "If entered only as help, show the list of available help topics, when also command entered, show the information about the selected command.")
  helpContent["merge commands"] = HelpEntry(
      usage: "command [&& or ||] command ...",
      content: "Commands can be merged to execute each after another. If merged with && then the next command(s) will be executed only when the previous was successfull. If merged with || then the next commands will be executed only when the previous failed.")

proc addCommand*(name: UserInput; command: CommandProc;
    commands: var CommandsList) {.gcsafe, raises: [], tags: [WriteIOEffect,
        RootEffect], contractual.} =
  require:
    name.len() > 0
    command != nil
  body:
    if $name in commands:
      showError(message = "Can't add command '" & $name & "' because there is one with that name.")
      return
    if $name in ["cd", "exit", "set", "unset"]:
      showError(message = "Can't replace built-in commands.")
      return
    try:
      commands[$name] = command
    except Exception:
      showError(message = "Can't add command '" & name & "'. Reason: ",
          e = getCurrentException())
