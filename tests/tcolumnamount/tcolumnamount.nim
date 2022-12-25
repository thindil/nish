discard """
  exitcode: 0
"""

import ../../src/columnamount

block:
  let code: ColumnAmount = 42.ColumnAmount
  assert code == 42, "Failed to compare ColumnAmount."

  assert (12.ColumnAmount / 2).int == 6, "Failed to divide ColumnAmount"
  assert (10.ColumnAmount - 5) == 5, "Failed to substract ColumnAmount"
  assert (5.ColumnAmount * 2) == 10, "Failed to multiply ColumnAmount"
