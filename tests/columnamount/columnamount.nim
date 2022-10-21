discard """
  exitcode: 0
"""

import ../../src/columnamount

let code: ColumnAmount = 42.ColumnAmount
assert code == 42

assert (12.ColumnAmount / 2).int == 6
assert (10.ColumnAmount - 5) == 5
assert (5.ColumnAmount * 2) == 10
