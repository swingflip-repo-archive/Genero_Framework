# ------------------------------------------------------------------------------
# Database re-sync script for SQLite
#
# Note: This script is a helper script to resync a database from your source to
#       to the working directory of the application
# ------------------------------------------------------------------------------
MAIN
    CALL db_resync("local.db","bin") #This will destroy any db located in your working directory and replace it from the database
                                     #folder.
END MAIN
