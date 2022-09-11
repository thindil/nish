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

import std/[db_sqlite, tables]
import contracts
import constants, lstring, output, resultcode

type
  CommandLists* = object
    ## FUNCTION
    ##
    ## Store additional data for the shell's command
    help*: ref HelpTable ## List with the content of the shell's help
    aliases*: ref AliasesList ## List of shell's aliases
    plugins*: ref PluginsList ## List of enables shell's plugins
  CommandProc* = proc (arguments: UserInput; db: DbConn;
      list: CommandLists): ResultCode {.gcsafe, raises: [], contractual.}
    ## FUNCTION
    ##
    ## The shell's command's code
    ##
    ## PARAMETERS
    ##
    ## * arguments - the arguments entered by the user for the command
    ## * db        - the connection to the shell's database
    ## * list      - the additional data for the command, like list of help
    ##               entries, etc
    ##
    ## RETURNS
    ##
    ## QuitSuccess if the command was succesfull, otherwise QuitFalse
  CommandsList* = Table[string, CommandProc]
    ## FUNCTION
    ##
    ## Used to store the shell's commands

proc addCommand*(name: UserInput; command: CommandProc;
    commands: var CommandsList) {.gcsafe, sideEffect, raises: [], tags: [
    WriteIOEffect, RootEffect], contractual.} =
  ## FUNCTION
  ##
  ## Add a new command to the shell's commands' list
  ##
  ## PARAMETERS
  ##
  ## * name     - the name of the new command to add
  ## * command  - the pointer to the procedure which will be called when the
  ##              command is invoked
  ## * commands - the list of shell's commands
  ##
  ## RETURNS
  ##
  ## The updated parameter commands with the list of available shell's commands
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
