discard """
  exitcode: 0
"""

import ../../src/variables

assert buildQuery("/", "name") == "SELECT name FROM variables WHERE path='/' ORDER BY id ASC"
