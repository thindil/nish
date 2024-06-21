# Copyright © 2024 Bartek Jasicki
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

## Various code used in the program's tests, like initialization of database,
## adding testing alias, etc

import std/[files, paths]
import ../../src/[aliases, db, types]
import norm/sqlite
import contracts

proc initDb*(dbName: Path): DbConn {.raises: [], tags: [RootEffect],
    contractual.} =
  ## Initialize the shell's database
  ##
  ## * dbName - the path to the database's file
  ##
  ## Returns the connection to the database or nil if there was an error.
  require:
    dbName.len > 0
  ensure:
    result != nil
  body:
    result = startDb(dbPath = dbName)

proc addAliases*(db: DbConn) {.raises: [DbError, ValueError], tags: [
    ReadDbEffect, WriteDbEffect], contractual.} =
  ## Add testing aliases to the shell.
  ##
  ## * db - the connection to the shell's database
  if db.count(T = Alias) == 0:
    var alias: Alias = newAlias(name = "tests", path = "/".Path, recursive = true,
          commands = "ls -a", description = "Test alias.", output = "output")
    db.insert(obj = alias)
    var testAlias2: Alias = newAlias(name = "tests2", path = "/".Path,
        recursive = false, commands = "ls -a", description = "Test alias 2.",
            output = "output")
    db.insert(obj = testAlias2)

proc removeDb*(dbName: Path; db: DbConn) {.raises: [], tags: [DbEffect,
    WriteDirEffect, ReadDirEffect], contractual.} =
  ## Close the shell's database and remove its file
  ##
  ## * dbName - the path to the database's file
  ## * db     - the connection to the database
  require:
    dbName.len > 0
    db != nil
  ensure:
    not dbName.fileExists
  body:
    try:
      db.close
      dbName.removeFile
    except:
      echo getCurrentExceptionMsg()
