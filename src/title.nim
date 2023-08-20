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

## This module contains code to set the terminal's window title, based on the
## shell's setting and avaiablitity.

# Standard library imports
import std/[os, terminal]
# External modules imports
import contracts, db_sqlite
# Internal imports
import lstring, options

proc setTitle*(title: string; db: DbConn) {.gcsafe, sideEffect, raises: [],
    tags: [WriteIOEffect, TimeEffect, ReadEnvEffect, ReadDbEffect, RootEffect],
    contractual.} =
  ## Set the title of the terminal if the proper shell's option is enabled
  ##
  ## * title - the new title for the terminal
  ## * db    - the connection to the shell's database
  require:
    db != nil
  body:
    # Not a terminal emulator, don't set the title
    if not stdin.isatty and not stdout.isatty:
      return
    try:
      if getOption(optionName = initLimitedString(capacity = 8,
          text = "setTitle"), db = db, defaultValue = initLimitedString(
          capacity = 4, text = "true")) == "false":
        return
    except CapacityError:
      return
    try:
      stdout.write(s = "\e]2;" & title & "\a")
      stdout.flushFile
    except IOError:
      discard
