discard """
  exitcode: 0
"""

import ../../src/databaseid

assert $12.Databaseid == "12", "Failed to convert Databaseid to string"
