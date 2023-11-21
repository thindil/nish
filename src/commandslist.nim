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

## This module contains code related to the shell's commands, like adding,
## deleting, replacing them.

# Standard library imports
import std/tables
# External modules imports
import contracts
import norm/sqlite
# Internal imports
import constants, lstring, output, resultcode

type
  CommandLists* = object
    ## Store additional data for the shell's command
    aliases*: ref AliasesList                 ## List of shell's aliases
    commands*: ref Table[string, CommandData] ## List of the shell's commands
  CommandProc* = proc (arguments: UserInput; db: DbConn;
      list: CommandLists): ResultCode {.raises: [], contractual.}
    ## The shell's command's code
    ##
    ## * arguments - the arguments entered by the user for the command
    ## * db        - the connection to the shell's database
    ## * list      - the additional data for the command, like list of help
    ##               entries, etc
    ##
    ## Returns QuitSuccess if the command was succesfull, otherwise QuitFalse
  CommandData* = object
    ## The data structure for the shell command
    ##
    ## * command     - the shell's command procedure which will be executed
    ## * plugin      - the name of the plugin to which the command belongs
    ## * subcommands - the list of subcommands available for the command
    command*: CommandProc
    plugin*: string
    subcommands*: seq[string]
  CommandsList* = Table[string, CommandData]
    ## Used to store the shell's commands
  CommandsListError* = object of CatchableError
    ## Raised when a problem with a command occurs

proc addCommand*(name: UserInput; command: CommandProc;
    commands: ref CommandsList; plugin: string = ""; subCommands: seq[
    string] = @[]) {.sideEffect, raises: [CommandsListError], tags: [
    WriteIOEffect, RootEffect], contractual.} =
  ## Add a new command to the shell's commands' list. If command argument is
  ## different than nil, it will be used as the command code, otherwise, the
  ## argument plugin must be supplied.
  ##
  ## * name        - the name of the new command to add
  ## * command     - the pointer to the procedure which will be called when the
  ##                 command is invoked
  ## * commands    - the list of shell's commands
  ## * plugin      - the full path to the plugin which contains the code for the
  ##                 command
  ## * subcommands - the list of the subcommands available for the command
  ##
  ## Returns the updated parameter commands with the list of available shell's commands
  require:
    name.len > 0
    command != nil or plugin.len > 0
  body:
    if $name in commands:
      raise newException(exceptn = CommandsListError,
          message = "Command with name '" & $name & "' exists.")
    if $name in builtinCommands:
      raise newException(exceptn = CommandsListError,
          message = "Can't replace built-in commands.")
    commands[$name] = CommandData(command: command, plugin: plugin,
        subcommands: subCommands)

proc deleteCommand*(name: UserInput; commands: ref CommandsList) {.sideEffect,
    raises: [CommandsListError], tags: [], contractual.} =
  ## Delete the selected command from the shell's commands' list
  ##
  ## * name     - the name of the new command to delete
  ## * commands - the list of shell's commands
  ##
  ## Returns the updated parameter commands with the list of available shell's commands
  require:
    name.len > 0
    commands.len > 0
  body:
    if $name notin commands:
      raise newException(exceptn = CommandsListError,
          message = "Command with name '" & $name & "' doesn't exists.")
    commands.del(key = $name)

proc replaceCommand*(name: UserInput; command: CommandProc;
    commands: ref CommandsList; plugin: string = "") {.sideEffect, raises: [
    CommandsListError], tags: [RootEffect], contractual.} =
  ## Replace the code of the selected command with the new procedure. If
  ## command argument is different than nil, it will be used as the command
  ## code, otherwise, the argument plugin must be supplied.
  ##
  ## * name     - the name of the new command to delete
  ## * command  - the pointer to the procedure which will replace the existing
  ##              procedure
  ## * commands - the list of shell's commands
  ## * plugin   - the full path to the plugin which contains the code for the
  ##              command
  ##
  ## Returns the updated parameter commands with the list of available shell's commands
  require:
    name.len > 0
    commands.len > 0
    command != nil or plugin.len > 0
  body:
    if $name notin commands:
      raise newException(exceptn = CommandsListError,
          message = "Command with name '" & $name & "' doesn't exists.")
    try:
      commands[$name].command = command
      commands[$name].plugin = plugin
    except KeyError:
      showError(message = "Can't replace command '" & name & "'. Reason: ",
          e = getCurrentException())
