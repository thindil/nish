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

import std/tables
import lstring

const maxNameLength*: Positive = 50
  ## FUNCTION
  ##
  ## Max allowed length of various names (options, variables, etc). Can be
  ## customized separately for each name's type either in the proper modules.

type
  HelpEntry* = object
    ## FUNCTION
    ##
    ## Used to store the shell's help entries
    usage*: string   ## The shell's command to enter for the selected entry
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
