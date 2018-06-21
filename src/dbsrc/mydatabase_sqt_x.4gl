# ------------------------------------------------------------------------------
# Database creation script for SQLite
#
# Note: This script is a helper script to create an empty database schema
#       Adapt it to fit your needs
# ------------------------------------------------------------------------------

MAIN
    DATABASE mydatabase

    CALL db_drop_tables()
    CALL db_create_tables()
END MAIN

{
  db_create_tables

  Create all tables in database.
}
FUNCTION db_create_tables()
    WHENEVER ERROR CONTINUE

    EXECUTE IMMEDIATE "CREATE TABLE seqreg (
        sr_name VARCHAR(30) NOT NULL,
        sr_last INTEGER NOT NULL,
        CONSTRAINT pk_seqreg PRIMARY KEY(sr_name))"

    WHENEVER ERROR STOP
END FUNCTION

{
  db_drop_tables

  Drop all tables from database.
}
FUNCTION db_drop_tables()
    WHENEVER ERROR CONTINUE

    EXECUTE IMMEDIATE "DROP TABLE seqreg"

    WHENEVER ERROR STOP
END FUNCTION


