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
import lstring, resultcode

const
  maxNameLength*: Positive = 50
    ## FUNCTION
    ##
    ## Max allowed length of various names (options, variables, etc). Can be
    ## customized separately for each name's type either in the proper modules.
  aliasNameLength*: Positive = maxNameLength
    ## FUNCTION
    ##
    ## The maximum length of the shell's alias namev

type
  HelpEntry* = object
    ## FUNCTION
    ##
    ## Used to store the shell's help entries
    usage*: string ## The shell's command to enter for the selected entry
    content*: string ## The content of the selected entry
  HelpTable* = Table[string, HelpEntry]
    ## FUNCTION
    ##
    ## Used to store the shell's help content
  UserInput* = LimitedString
    ## FUNCTION
    ##
    ## Used to store text entered by the user
  ExtendedNatural* = range[-1..high(int)]
    ## FUNCTION
    ##
    ## Used to store various indexes
  BooleanInt* = range[0..1]
    ## FUNCTION
    ##
    ## Used to store boolean values in database
  HistorySort* = enum
    ## FUNCTION
    ##
    ## Used to set the sort type for showing the last commands in the shell's
    ## history
    recent, amount, name, recentamount
  AliasName* = LimitedString
    ## FUNCTION
    ##
    ## Used to store aliases names in tables and database.
  AliasesList* = OrderedTableRef[AliasName, int]
    ## FUNCTION
    ##
    ## Used to store the available aliases in the selected directory
  PluginData* = object
    ## FUNCTION
    ##
    ## Store information about the shell's plugin
    path*: string ## Full path to the selected plugin
    api*: seq[string] ## The list of API calls supported by the plugin
  PluginsList* = TableRef[string, PluginData]
    ## FUNCTION
    ##
    ## Used to store the enabled shell's plugins
  CommandLists* = object
    ## FUNCTION
    ##
    ## Store additional data for the shell's command
    help*: ref HelpTable ## List with the content of the shell's help
    aliases*: AliasesList ## List of shell's aliases
    plugins*: PluginsList ## List of enables shell's plugins
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
