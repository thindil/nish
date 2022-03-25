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
import aliases, constants, history, output, variables

using
  db: DbConn # Connection to the shell's database
  aliases: var OrderedTable[string, int] # The list of aliases available in the selected directory
  newDirectory: string # The directory to which the current directory will be changed

proc changeDirectory*(newDirectory; aliases; db): int {.gcsafe, sideEffect,
    raises: [ValueError], tags: [ReadEnvEffect, ReadIOEffect, ReadDbEffect,
    WriteIOEffect, ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Change the current directory for the shell
  ##
  ## PARAMETERS
  ## * newDirectory - the path to the new directory to which the current
  ##                  working directory will be changed
  ## * aliases      - the list of available aliases in the current directory
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the working directory was properly changed, otherwise
  ## QuitFailure. Also, updated parameter aliases.
  try:
    var path: string = absolutePath(expandTilde(newDirectory))
    if not dirExists(path):
      return showError("Directory '" & path & "' doesn't exist.")
    path = expandFilename(path)
    setVariables(path, db, getCurrentDir())
    setCurrentDir(path)
    aliases.setAliases(path, db)
    return QuitSuccess
  except OSError:
    return showError()

proc cdCommand*(newDirectory; aliases; db): int {.gcsafe, sideEffect, raises: [
    ValueError], tags: [ReadEnvEffect, ReadIOEffect, ReadDbEffect,
    WriteIOEffect, WriteDbEffect, ReadEnvEffect, TimeEffect].} =
  ## Build-in command to enter the selected by the user directory
  if newDirectory.len() == 0:
    result = changeDirectory("~", aliases, db)
    discard updateHistory("cd ~", db, result)
  else:
    result = changeDirectory(newDirectory, aliases, db)
    discard updateHistory("cd " & newDirectory, db, result)

func initCommands*(helpContent: var HelpTable) {.gcsafe, locks: 0, raises: [],
    tags: [].} =
  ## Initialize the shell's build-in commands. At this moment only set help
  ## related to the commands
  helpContent["cd"] = HelpEntry(usage: "cd ?directory?",
      content: "You must have permissions to enter the directory and directory need to exists. If you enter just 'cd' without the name of the directory to enter, the current directory will be switched to your home directory.")
  helpContent["exit"] = HelpEntry(usage: "exit",
      content: "Exit from the shell.")
  helpContent["help"] = HelpEntry(usage: "help ?command?",
      content: "If entered only as help, show the list of available help topics, when also command entered, show the information about the selected command.")
  helpContent["merge commands"] = HelpEntry(
      usage: "command [&& or ||] command ...",
      content: "Commands can be merged to execute each after another. If merged with && then the next command(s) will be executed only when the previous was successfull. If merged with || then the next commands will be executed only when the previous failed.")
