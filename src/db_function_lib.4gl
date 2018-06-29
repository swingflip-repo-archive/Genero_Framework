IMPORT SECURITY
IMPORT com
IMPORT util
IMPORT os
IMPORT FGL function_lib

  PRIVATE DEFINE
    f_current_DT DATETIME YEAR TO SECOND

FUNCTION db_create_tables() #**************************************************#

  TRY
    EXECUTE IMMEDIATE "CREATE TABLE local_stat (
      l_s_index INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
      deployment_type VARCHAR(255) NOT NULL,
      os_type VARCHAR(255) NOT NULL,
      ip VARCHAR(255),
      device_name VARCHAR(255),
      resolution VARCHAR(255),
      geo_location VARCHAR(255),
      last_load DATETIME NOT NULL
      );"

    EXECUTE IMMEDIATE "CREATE TABLE local_accounts (
      l_u_index INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
      username VARCHAR(255) NOT NULL,
      password VARCHAR(255) NOT NULL,
      email VARCHAR(255),
      phone INTEGER,
      last_login DATETIME,
      user_type VARCHAR(5),
      CONSTRAINT l_u_unique UNIQUE (username)
      );"

    EXECUTE IMMEDIATE "CREATE TABLE local_remember (
      l_r_index INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
      username VARCHAR(255),
      remember SMALLINT NOT NULL,
      last_modified DATETIME
      );"

    EXECUTE IMMEDIATE "CREATE TABLE payload_queue (
      p_q_index INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
      requested_by VARCHAR(255) NOT NULL,
      requested_date DATETIME NOT NULL,
      last_attempted DATETIME,
      destination VARCHAR(255) NOT NULL,
      payload_type VARCHAR(64) NOT NULL,
      payload BLOB NOT NULL
      );"

    EXECUTE IMMEDIATE "CREATE TABLE database_version (
      d_v_index INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
      db_version INTEGER,
      last_updated DATETIME
      );"
  CATCH
    DISPLAY "CREATE: " || STATUS || " " || SQLERRMESSAGE
  END TRY
  
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION db_create_defaults() #************************************************#

  TRY
    LET f_current_DT = CURRENT
    EXECUTE IMMEDIATE "DELETE FROM local_remember"
    EXECUTE IMMEDIATE "INSERT INTO local_remember VALUES(NULL,NULL,0,NULL)"
    EXECUTE IMMEDIATE "INSERT INTO database_version VALUES(NULL,1,\""||f_current_DT||"\")"
  CATCH
    DISPLAY "DEFAULTS: " || STATUS || " " || SQLERRMESSAGE
  END TRY
  
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION db_drop_tables() #****************************************************#

  WHENEVER ERROR CONTINUE #We don't know the integrety of the database so we won't use a TRY/CATCH
    EXECUTE IMMEDIATE "DROP TABLE database_version"
    EXECUTE IMMEDIATE "DROP TABLE local_stat"
    EXECUTE IMMEDIATE "DROP TABLE local_accounts"
    EXECUTE IMMEDIATE "DROP TABLE local_remember"
    EXECUTE IMMEDIATE "DROP TABLE payload_queue"
  WHENEVER ERROR STOP
  
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION db_resync(f_dbname STRING,f_external_path STRING) #*******************#

  DEFINE
    f_dbpath STRING

  IF f_external_path IS NOT NULL
  THEN
    LET f_dbpath = os.path.join(os.path.join(os.path.join(os.path.pwd(), ".."), f_external_path), f_dbname)
  ELSE
    LET f_dbpath = os.path.join(os.path.pwd(), f_dbname)
  END IF

  DISPLAY f_dbpath
  IF os.path.delete(f_dbpath)
  THEN
    DISPLAY "Working directory database deleted! Initiating openDB()"
    CALL openDB(f_dbname,TRUE)
  ELSE
    DISPLAY "ERROR: COULDN'T REMOVE WORKING DIRECTORY DATABASE"
    EXIT PROGRAM 9999
  END IF
        
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION openDB(f_dbname STRING,f_debug SMALLINT) #****************************#

  DEFINE 
    f_dbpath STRING,
    f_db_dbname STRING,
    f_msg STRING

  LET f_dbpath = os.path.join(os.path.pwd(), f_dbname)
  LET f_db_dbname = os.path.join("..","database")
  LET f_db_dbname = os.path.join(base.Application.getProgramDir(),f_db_dbname)
      
  IF NOT os.path.exists(f_dbpath) #Check working directory for local.db
  THEN
    LET f_msg = "db missing, "
    IF NOT os.path.exists(os.path.join(base.Application.getProgramDir(),f_dbname)) #Check app directory for local.db
    THEN
      IF NOT os.path.exists(os.path.join(f_db_dbname,f_dbname)) # Check app/../databse for local.db
      THEN
        DISPLAY "FATAL ERROR: You don't have a database set up! Run the CreateDatabase application within the toolbox!"
        EXIT PROGRAM 9999
      ELSE
        IF os.path.copy(os.path.join(f_db_dbname,f_dbname), f_dbpath)
        THEN
          LET f_msg = f_msg.append("Copied ")
        ELSE
          LET f_msg = f_msg.append("Database Copy failed! ")
        END IF
      END IF
    ELSE
      IF os.path.copy(os.path.join(base.Application.getProgramDir(),f_dbname), f_dbpath)
      THEN
        LET f_msg = f_msg.append("Copied ")
      ELSE
        LET f_msg = f_msg.append("Database Copy failed! ")
      END IF
    END IF
  ELSE
    LET f_msg = "db exists, "
  END IF
  TRY
    DATABASE f_dbpath
    LET f_msg = f_msg.append("Connected OK")
    CALL check_database_version(FALSE)
  CATCH
    DISPLAY STATUS || " " || f_msg || SQLERRMESSAGE
  END TRY

  IF f_debug = TRUE
  THEN
    DISPLAY f_msg
  END IF
    
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION check_database_version (f_debug SMALLINT) #***************************#

  DEFINE
    f_count INTEGER,
    f_version INTEGER,
    f_msg STRING
        
  SELECT COUNT(*) INTO f_count FROM database_version

  IF f_count = 0
  THEN
    LET f_msg = "No database version within working db, "
    TRY
      LET f_current_DT = CURRENT
      INSERT INTO database_version VALUES(NULL, global_config.application_database_ver, f_current_DT)
    CATCH
      DISPLAY STATUS || " " || SQLERRMESSAGE
    END TRY

    IF sqlca.sqlcode <> 0
    THEN
      LET f_msg = f_msg.append("Database version insert failed!")
      DISPLAY "FATAL ERROR: You must have an invalid db version number set in the global config, please fix and try again!"
      EXIT PROGRAM 9999
    ELSE
      LET f_msg = f_msg.append("Database version insert OK!\n")
    END IF
  ELSE
    LET f_msg="Database Version OK,\n"
  END IF

  SELECT db_version INTO f_version FROM database_version

  IF f_version != global_config.application_database_ver
  THEN
    LET f_msg = f_msg.append("Database version mismatch! Running db_create_tables()...\n")
    CALL db_create_tables() #Before this runs, you need to be confident that this function will work the way you want it... You have been warned!
    TRY
      LET f_current_DT = CURRENT
      UPDATE database_version SET db_version = global_config.application_database_ver, last_updated = f_current_DT
    CATCH
      DISPLAY STATUS || " " || SQLERRMESSAGE
    END TRY

    IF sqlca.sqlcode <> 0
    THEN
      LET f_msg = f_msg.append("Database version update failed!")
      DISPLAY "FATAL ERROR: DB version update failed, you must have an issue with your database_version table!"
      EXIT PROGRAM 9999
    ELSE
      LET f_msg = f_msg.append("Database version updated OK!\n")
    END IF
  ELSE
    LET f_msg = f_msg.append("Database is up to date!")
  END IF

  IF f_debug = TRUE
  THEN
    DISPLAY f_msg
  END IF      
    
END FUNCTION #*****************************************************************#