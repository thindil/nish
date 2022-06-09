discard """
  exitcode: 0
"""

import ../../src/columnamount

assert (12.ColumnAmount / 2).int == 6
assert (10.ColumnAmount - 5) == 5
assert (5.ColumnAmount * 2) == 10
