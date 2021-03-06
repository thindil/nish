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

import std/[os, strutils]
import output

proc getCompletion*(prefix: string): string {.gcsafe, sideEffect, raises: [],
    tags: [ReadDirEffect, WriteIOEffect].} =
  ## FUNCTION
  ##
  ## Get the relative path of file or directory, based on the selected prefix
  ## in the current directory.
  ##
  ## PARAMETERS
  ##
  ## * prefix - the prefix which will be looking for in the current directory
  ##
  ## RETURNS
  ##
  ## The relative path to the first file or directory which match the parameter
  ## prefix. If prefix is empty, or there is no matching file or directory,
  ## returns empty string.
  if prefix.len() == 0:
    return
  try:
    let
      parent: string = parentDir(path = prefix)
      dirToCheck = getCurrentDir() & (if dirExists(dir = parent): DirSep &
          parent else: "")
      newPrefix: string = (if dirToCheck != getCurrentDir(): lastPathPart(
          path = prefix) else: prefix)
    for item in walkDir(dir = dirToCheck, relative = true):
      if item.path.startsWith(prefix = newPrefix):
        return (if parent != ".": parent & DirSep else: "") & item.path
  except OSError:
    discard showError(message = "Can't get completion. Reason: ",
        e = getCurrentException())
