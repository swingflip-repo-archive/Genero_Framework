IMPORT SECURITY
IMPORT com
IMPORT util
IMPORT os
IMPORT FGL fgldialog
SCHEMA local

  PUBLIC DEFINE
    global_config RECORD
      application_db_ver INTEGER,                     #Application Database Version
      application_db_external SMALLINT,               #Toggle to use external DB or local.db
      application_db_external_dbname STRING,          #External DB name if using external DB (Ties into config within FGLPROFILE)
      application_db_external_driver STRING,          #External DB driver if using external DB (dbmmys_5_5 (mariaDB))
      application_db_external_config STRING,          #External DB config if using external DB (i.e. /etc/mysql/my.cnf)
      application_db_external_username STRING,        #External DB username if using external DB
      application_db_external_password STRING,        #External DB password if using external DB
      application_db_external_extra_security SMALLINT,#Enable extra security on external DB (DB password displayed on new install)
      enable_geolocation SMALLINT,                    #Toggle to enable geolocation
      enable_mobile_title SMALLINT,                   #Toggle application title on mobile
      timed_checks_time INTEGER,                      #Time in seconds before running auto checks, uploads or refreshes (0 disables this globally)
      enable_timed_connect SMALLINT,                  #Enable timed connectivity checks
      enable_splash SMALLINT,                         #Open splashscreen when opening the application.
      splash_duration SMALLINT,                       #Splashscreen duration (seconds) enable_splash needs to be enabled!
      enable_login SMALLINT,                          #Boot in to login menu or straight into application (open_application())
      local_stat_limit INTEGER,                       #Number of max local stat records before pruning
      online_ping_URL STRING,                         #URL of public site to test internet connectivity (i.e. http://www.google.com) 
      date_format STRING,                             #Datetime format. i.e.  "%d/%m/%Y %H:%M"
      default_language STRING,                        #The default language used within the application (i.e. EN)
      local_images_available DYNAMIC ARRAY OF CHAR(2),#Available localisations for images.
      debug_level SMALLINT                            #Debug level // 0 - None, 1 - Verbose, 2 - 
    END RECORD,

    global_var RECORD
      application_title STRING,           #Application Title
      application_version STRING,         #Application Version
      application_about STRING,           #Application About Blurb
      title STRING,                       #Concatenated application title string
      online STRING,                      #BOOLEAN to determine if the application is online or offline
      user STRING,                        #Username of the user currently logged in
      user_type STRING,                   #User type currently logged in
      logged_in DATETIME YEAR TO SECOND,  #When the current user logged in to the system
      OK_uploads INTEGER,                 #Number of successful uploads just carried out
      FAILED_uploads INTEGER,             #Number of failed uploads just carried out
      language STRING,                    #Current user's selected language
      language_short STRING,              #The two character language code i.e. en instead of en_GB
      instruction STRING,                 #This is used to swap between windows and forms
      info RECORD                         #Used to store information regarding client deployment
        deployment_type STRING,
        os_type STRING,
        ip STRING,
        device_name STRING,
        resolution STRING,
        resolution_x STRING,
        resolution_y STRING,
        geo_status STRING,
        geo_lat STRING,
        geo_lon STRING,
        locale STRING
      END RECORD
    END RECORD

  PRIVATE DEFINE
    f_current_DT DATETIME YEAR TO SECOND

FUNCTION sync_config(f_config_name STRING,f_debug SMALLINT) #******************#

  DEFINE 
    f_configpath STRING,
    f_config_configname STRING,
    f_msg STRING

  LET f_configpath = os.path.join(os.path.pwd(), f_config_name)
  LET f_config_configname = os.path.join("..","config")
  LET f_config_configname = os.path.join(base.Application.getProgramDir(),f_config_configname)
        
  IF NOT os.path.exists(f_configpath) #Check working directory for config file
  THEN
    LET f_msg = "Config file missing, "
    IF NOT os.path.exists(os.path.join(base.Application.getProgramDir(),f_config_name)) #Check app directory for config file
    THEN
      IF NOT os.path.exists(os.path.join(f_config_configname,f_config_name)) # Check app/../config for config file
      THEN
        DISPLAY "FATAL ERROR: You don't have a config file set up!"
        EXIT PROGRAM 9999
      ELSE
        IF os.path.copy(os.path.join(f_config_configname,f_config_name), f_configpath)
        THEN
          LET f_msg = f_msg.append("Copied config")
        ELSE
          LET f_msg = f_msg.append("Config copy failed! ")
        END IF
      END IF
    ELSE
      IF os.path.copy(os.path.join(base.Application.getProgramDir(),f_config_name), f_configpath)
      THEN
        LET f_msg = f_msg.append("Copied config")
      ELSE
        LET f_msg = f_msg.append("Config copy failed! ")
      END IF
    END IF
  ELSE
    LET f_msg = "config exists, checking for master config for resync... "
    IF os.path.exists(os.path.join(f_config_configname,f_config_name)) # Check app/../config for config file
    THEN
      IF os.path.copy(os.path.join(f_config_configname,f_config_name), f_configpath)
      THEN
        LET f_msg = f_msg.append("Re-synced the config OK")
      ELSE
        LET f_msg = f_msg.append("Config re-sync failed! ")
      END IF
    ELSE
      LET f_msg = f_msg.append(" In production deployment. Contiuning as normal.")
    END IF
  END IF

  IF f_debug = TRUE
  THEN
    DISPLAY f_msg
  END IF
    
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION initialize_publics() #************************************************#
  RETURNS BOOLEAN
  
  DEFINE
    f_channel base.Channel,
    f_string_line STRING

  LET f_channel = base.Channel.create()
  TRY
    CALL f_channel.openFile(os.path.join(os.path.pwd(),"app.config"),"r")
  CATCH
    RETURN FALSE
  END TRY
  WHILE NOT f_channel.isEof()
    LET f_string_line = f_string_line.append( f_channel.readLine() ) 
  END WHILE
  CALL f_channel.close() 

  CALL util.JSON.parse( f_string_line, global_config)

  #Extra Security (Not fool proof but prevents basic hacking)
  IF global_config.application_db_external = TRUE AND global_config.application_db_external_extra_security = TRUE
  THEN 
    CALL Generate_Hash(global_config.application_db_external_password ||
                       global_config.application_db_external_dbname ||
                       global_config.application_db_external_username, "SHA256") 
      RETURNING global_config.application_db_external_password
    #CALL fgl_winmessage("Hashed Value",global_config.application_db_external_password,"information") #Comment when not in use!
  END IF

  RETURN TRUE
    
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION test_connectivity(f_deployment_type STRING) #*************************#

  DEFINE
    f_connectivity STRING,
    f_req com.HttpRequest,
    f_resp com.HttpResponse,
    f_resp_code INTEGER

  IF f_deployment_type = "GMA" OR f_deployment_type = "GMI"
  THEN
    CALL ui.Interface.frontCall("mobile", "connectivity", [], [f_connectivity])
  ELSE
    TRY
      LET f_req = com.HttpRequest.Create(global_config.online_ping_URL)
      CALL f_req.setHeader("PingHeader","High Priority")
      CALL f_req.doRequest()
      LET f_resp = f_req.getResponse()
      LET f_resp_code = f_resp.getStatusCode()
      IF f_resp.getStatusCode() != 200 THEN
        IF global_config.debug_level >= 1
        THEN
          DISPLAY "HTTP Error (" || f_resp.getStatusCode() || ") " || f_resp.getStatusDescription()
        END IF
        LET f_connectivity = "NONE"
        MESSAGE %"common.string.Working_Offline"
      ELSE
        LET f_connectivity = "WIFI"
      END IF
    CATCH
      IF global_config.debug_level >= 1
      THEN
        DISPLAY "ERROR :" || STATUS || " (" || SQLCA.SQLERRM || ")"
      END IF
      LET f_connectivity = "NONE"
      MESSAGE %"common.string.Working_Offline"
    END TRY
  END IF

  LET global_var.online = f_connectivity
  
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION capture_local_stats(f_info) #*****************************************#
  RETURNS BOOLEAN
  
  DEFINE
    f_info RECORD
      deployment_type STRING,
      os_type STRING,
      ip STRING,
      device_name STRING,
      resolution STRING,
      resolution_x STRING,
      resolution_y STRING,
      geo_status STRING,
      geo_lat STRING,
      geo_lon STRING,
      locale STRING
    END RECORD,
    f_concat_geo STRING,
    f_count INTEGER

  IF global_config.debug_level >= 2 
  THEN
    CALL openDB("local.db",TRUE)
  ELSE
    CALL openDB("local.db",FALSE)
  END IF
  
  LET f_concat_geo = f_info.geo_lat || "*" || f_info.geo_lon # * is the delimeter.
  TRY
    LET f_current_DT = CURRENT
    INSERT INTO local_stat VALUES(NULL, f_info.deployment_type, f_info.os_type, f_info.ip, f_info.device_name, f_info.resolution,  f_concat_geo, f_current_DT)
  CATCH
    DISPLAY STATUS || " " || SQLERRMESSAGE
  END TRY

  IF sqlca.sqlcode <> 0
  THEN
    CALL fgl_winmessage(%"common.string.Fatal_Error", %"error.string.ERROR_1002", "stop")
    EXIT PROGRAM 1002
  END IF

  #We don't want the local stat table getting too big so lets clear down old data as we go along...
  SELECT COUNT(*) INTO f_count FROM local_stat

  IF f_count >= global_config.local_stat_limit
  THEN
    TRY
      DELETE FROM local_stat WHERE l_s_index = (SELECT MIN(l_s_index) FROM local_stat)
    CATCH
      DISPLAY STATUS || " " || SQLERRMESSAGE
    END TRY

    IF sqlca.sqlcode <> 0
    THEN
      CALL fgl_winmessage(%"common.string.Fatal_Error", %"error.string.ERROR_1003", "stop")
      EXIT PROGRAM 1003
    END IF
  END IF
  
  RETURN TRUE #legacy
  
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION check_new_install() #*************************************************#
  RETURNS SMALLINT
  
  DEFINE
    f_count INTEGER

  #0-USERFOUND,#1-NEWINSTALL,#2-DBERROR

  IF global_config.debug_level >= 2 
  THEN
    CALL openDB("local.db",TRUE)
  ELSE
    CALL openDB("local.db",FALSE)
  END IF
  
  TRY
    SELECT COUNT(*) INTO f_count FROM local_accounts
  CATCH
    DISPLAY STATUS || " " || SQLERRMESSAGE
    CALL fgl_winmessage("ERROR", STATUS || " " || SQLERRMESSAGE, "stop")
    RETURN 2
  END TRY

  IF f_count == 0 
  THEN
    RETURN 1
  ELSE
    RETURN 0
  END IF
    
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION hash_password(f_pass STRING) #****************************************#
  RETURNS (BOOLEAN, STRING)

  DEFINE
    salt STRING,
    hashed_pass STRING,
    f_ok BOOLEAN
    
  LET f_ok = FALSE

  LET salt = Security.BCrypt.GenerateSalt(12)

  CALL Security.BCrypt.HashPassword(f_pass, salt) RETURNING hashed_pass

  IF Security.BCrypt.CheckPassword(f_pass, hashed_pass) THEN
    LET f_ok = TRUE
  ELSE
    LET f_ok = FALSE
  END IF

  RETURN f_ok, hashed_pass
  
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION check_password(f_user STRING,f_pass STRING) #*************************#
  RETURNS BOOLEAN

  DEFINE
    hashed_pass STRING,
    f_user_type STRING

  SELECT password,user_type INTO hashed_pass,f_user_type FROM local_accounts WHERE username = f_user

  IF hashed_pass IS NULL
  THEN
    RETURN FALSE
  ELSE
    IF Security.BCrypt.CheckPassword(f_pass, hashed_pass) THEN
      LET global_var.user = f_user
      LET global_var.user_type = f_user_type
      LET global_var.logged_in = CURRENT YEAR TO SECOND
      RETURN TRUE
    ELSE
      RETURN FALSE
    END IF
  END IF

  RETURN FALSE
  
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION get_local_remember() #************************************************#
  RETURNS (BOOLEAN, BOOLEAN, LIKE local_accounts.username)

  DEFINE
    f_remember BOOLEAN,
    f_username LIKE local_accounts.username,
    f_ok BOOLEAN

  IF global_config.debug_level >= 2 
  THEN
    CALL openDB("local.db",TRUE)
  ELSE
    CALL openDB("local.db",FALSE)
  END IF

  LET f_ok = FALSE

  SELECT remember, username INTO f_remember, f_username FROM local_remember

  IF f_remember = FALSE
  THEN
    LET f_username = ""
  END IF

  RETURN f_ok, f_remember, f_username
    
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION refresh_local_remember(f_username STRING,f_remember BOOLEAN) #********#
  RETURNS BOOLEAN

  IF global_config.debug_level >= 2 
  THEN
    CALL openDB("local.db",TRUE)
  ELSE
    CALL openDB("local.db",FALSE)
  END IF

  TRY
    LET f_current_DT = CURRENT
    UPDATE local_remember SET remember = f_remember, username = f_username, last_modified = f_current_DT
  CATCH
    DISPLAY STATUS || " " || SQLERRMESSAGE
  END TRY

  IF sqlca.sqlcode <> 0
  THEN
    CALL fgl_winmessage(%"common.string.Fatal_Error", %"error.string.ERROR_1005", "stop")
    EXIT PROGRAM 1005
  ELSE
    RETURN TRUE
  END IF

  RETURN FALSE
    
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION validate_input_data(f_input STRING, f_nulls BOOLEAN, #****************#
                             f_special_characters BOOLEAN,
                             f_safe_special_characters BOOLEAN,
                             f_numerals BOOLEAN, f_letters BOOLEAN,
                             f_spaces BOOLEAN, f_special_data_type STRING)
  RETURNS (STRING, BOOLEAN, STRING)
  
  IF f_nulls = FALSE AND f_input IS NULL
  THEN
    RETURN f_input, FALSE, "BAD_NULLS"
  END IF

  IF f_special_data_type IS NULL
  THEN
    IF f_special_characters = FALSE AND fgl_regex(f_input,"\~\#\$\%\^\&\*\(\)\+\"\{\}\|\<\>\?\-\=\[\]\/")
    THEN
      RETURN f_input, FALSE, "BAD_CHARS"
    END IF

    IF f_safe_special_characters = FALSE AND fgl_regex(f_input,"\@\_\,\.\!\'\:\;")
    THEN
      RETURN f_input, FALSE, "BAD_CHARS_2"
    END IF

    IF f_numerals = FALSE AND fgl_regex(f_input,"0123456789")
    THEN
      RETURN f_input, FALSE, "BAD_NUMERALS"
    END IF

    IF f_letters = FALSE AND fgl_regex(f_input,"abcdefghijklmnopqrstuvwxyz") #This should include foriegn letters too at some point.
    THEN
      RETURN f_input, FALSE, "BAD_LETTERS"
    END IF

    IF f_spaces = FALSE AND fgl_regex(f_input," ")
    THEN
      RETURN f_input, FALSE, "BAD_SPACES"
    END IF
  END IF 
    
  IF f_special_data_type = "EMAIL" AND f_input MATCHES "*@*.*" = FALSE
  THEN
    RETURN f_input, FALSE, "BAD_EMAIL"
  ELSE    
    #Can't use this as JAVA is not supported in GMI otherwise much cleaner solution...
    {IF fgl_regex(f_input,"\S+@\S+\.\S+") = FALSE
    THEN
      RETURN f_input, FALSE, "BAD_EMAIL"
    END IF}
  END IF

  IF f_special_data_type = "URL"
  THEN
    LET f_input = util.Strings.urlEncode(f_input) #Encode the data so it's safe and computer friendly
  END IF   

  RETURN f_input, TRUE, "OK"
    
END FUNCTION #*****************************************************************#
#
#
#
#
# This is the easiest way to regex input data however because JAVA is not currently supported by GMI,
# we have to use a FGL work around. Hopefully we will get a native FGL regex in the future...
{
FUNCTION contains_characters(f_string STRING,f_characters STRING) #************#
  RETURNS BOOLEAN
  
  DEFINE
    f_parameter STRING,
    f_pattern Pattern,
    f_matcher Matcher,

  LET f_parameter = "[" || f_characters || "]" 
  LET f_pattern = Pattern.compile(f_parameter)
  LET f_matcher = f_pattern.matcher(f_string)

  IF f_matcher.matches()
  THEN
    RETURN TRUE
  END IF

  RETURN FALSE
    
END FUNCTION #*****************************************************************#
}
#
#
#
#
FUNCTION fgl_regex(f_string STRING,f_characters STRING) #**********************#
  RETURNS BOOLEAN
  
  DEFINE
    f_integer INTEGER,
    f_integer2 INTEGER
        
  LET f_string = f_string.toUpperCase()
  LET f_characters = f_characters.toUpperCase()
  FOR f_integer = 1 TO f_string.getLength()
    FOR f_integer2 = 1 TO f_characters.getLength()
      IF f_characters.getCharAt( f_integer2 ) = f_string.getCharAt( f_integer )
      THEN
        RETURN TRUE 
      END IF
    END FOR
  END FOR
  
  RETURN FALSE
    
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION Generate_Hash(f_string STRING, f_algo STRING) #***********************#
  RETURNS STRING
  
  DEFINE f_digest security.Digest,
         f_result STRING

  TRY
    LET f_digest = security.Digest.CreateDigest(f_algo)
    CALL f_digest.AddStringData(f_string)
    LET f_result = f_digest.DoBase64Digest()
  CATCH
    DISPLAY "ERROR: FAILED TO HASH: " || STATUS || " " || SQLERRMESSAGE
    EXIT PROGRAM 9999
  END TRY

  RETURN f_result
  
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION set_localised_image(f_image STRING) #*********************************#
  RETURNS STRING
  
  IF global_config.default_language.toUpperCase() = global_var.language_short.toUpperCase()
  THEN
    RETURN f_image #Default language being used. Return default image
  ELSE
    IF global_config.local_images_available.search("",global_var.language_short.toUpperCase())
    THEN
      RETURN f_image || "_" || global_var.language_short.toLowerCase() #Localisation found. Return localised image
    END IF
  END IF
    
  RETURN f_image #We should never reach this point but just incase...
    
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION close_app() #*********************************************************#
  DISPLAY "Application exited successfully!"
  EXIT PROGRAM 1
END FUNCTION #*****************************************************************#
#
#
#
#
################################################################################
#
# Database Functions
#
################################################################################

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
    f_msg STRING,
    f_ext_connection STRING

  IF global_config.application_db_external == FALSE
  THEN #Local Database Conneciton
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
  ELSE
    LET f_ext_connection = global_config.application_db_external_dbname ||
                           "+driver='"    || global_config.application_db_external_driver   ||
                           "',source='"   || global_config.application_db_external_dbname   ||
                           "',username='" || global_config.application_db_external_username ||
                           "',password='" || global_config.application_db_external_password || "'"
      
    TRY 
      DATABASE f_ext_connection
    CATCH
      DISPLAY STATUS || " " || f_msg || SQLERRMESSAGE
    END TRY
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
      INSERT INTO database_version VALUES(NULL, global_config.application_db_ver, f_current_DT)
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

  IF f_version != global_config.application_db_ver
  THEN
    LET f_msg = f_msg.append("Database version mismatch! Running db_create_tables()...\n")
    CALL db_create_tables() #Before this runs, you need to be confident that this function will work the way you want it... You have been warned!
    TRY
      LET f_current_DT = CURRENT
      UPDATE database_version SET db_version = global_config.application_db_ver, last_updated = f_current_DT
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
