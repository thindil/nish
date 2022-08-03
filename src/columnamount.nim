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

type ColumnAmount* = distinct Natural
  ## FUNCTION
  ##
  ## Used to store length or amount of terminal's characters columns

func `/`*(x: ColumnAmount; y: int): ColumnAmount {.gcsafe, raises: [], tags: [], locks: 0.} =
  ## FUNCTION
  ##
  ## Used to divide ColumnAmount by integer
  ##
  ## PARAMETERS
  ##
  ## * x - The ColumnAmount value which will be divided
  ## * y - The int value which will be divider
  ##
  ## RESULT
  ##
  ## The result of dividing x by y converted to ColumnAmount
  return ColumnAmount(x.int / y)

proc `-`*(x: ColumnAmount; y: int): int {.borrow.}
 ## FUNCTION
 ##
 ## Used to substraction int from ColumnAmount. Borrowed from int type
 ##
 ## PARAMETERS
 ##
 ## * x - The ColumnAmount from which will be value will be substracted
 ## * y - The int which will be substracted from ColumnAmount value
 ##
 ## RESULT
 ##
 ## Substraction result of int from ColumnAmount

proc `*`*(x: ColumnAmount; y: int): int {.borrow.}
 ## FUNCTION
 ##
 ## Used to multiply ColumnAmount by int. Borrowed from int type
 ##
 ## PARAMETERS
 ##
 ## * x - The ColumnAmount which will be multiplied
 ## * y - The int which will be multiplier
 ##
 ## RESULT
 ##
 ## The x multiplied by y

proc `==`*(x: ColumnAmount; y: int): bool {.borrow.}
  ## FUNCTION
  ##
  ## Used to compare ColumnAmount with int. Borrowed from int type.
  ##
  ## PARAMETERS
  ##
  ## * x - The ColumnAmount to compare
  ## * y - The int to compare
  ##
  ## RETURNS
  ##
  ## True if both ColumnAmount and int are the same, otherwise false.
