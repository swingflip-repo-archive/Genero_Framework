IMPORT SECURITY
IMPORT com
IMPORT util
IMPORT os
IMPORT FGL fgldialog
IMPORT FGL db_function_lib
SCHEMA local

  PUBLIC DEFINE
    global_config RECORD
      application_database_ver INTEGER,               #Application Database Version
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
    
END FUNCTION  #****************************************************************#
#
#
#
#
FUNCTION initialize_publics() #************************************************#

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
        MESSAGE %"function.lib.string.Working_Offline"
      ELSE
        LET f_connectivity = "WIFI"
      END IF
    CATCH
      IF global_config.debug_level >= 1
      THEN
        DISPLAY "ERROR :" || STATUS || " (" || SQLCA.SQLERRM || ")"
      END IF
      LET f_connectivity = "NONE"
      MESSAGE %"function.lib.string.Working_Offline"
    END TRY
  END IF

  LET global_var.online = f_connectivity
  
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION capture_local_stats(f_info) #*****************************************#

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
    f_ok SMALLINT,
    f_count INTEGER

  CALL db_function_lib.openDB("local.db",FALSE)
  
  LET f_ok = FALSE
  LET f_concat_geo = f_info.geo_lat || "*" || f_info.geo_lon # * is the delimeter.
  TRY
    LET f_current_DT = CURRENT
    INSERT INTO local_stat VALUES(NULL, f_info.deployment_type, f_info.os_type, f_info.ip, f_info.device_name, f_info.resolution,  f_concat_geo, f_current_DT)
  CATCH
    DISPLAY STATUS || " " || SQLERRMESSAGE
  END TRY

  IF sqlca.sqlcode <> 0
  THEN
    CALL fgl_winmessage(%"function.lib.string.Fatal_Error", %"function.lib.string.ERROR_1002", "stop")
    EXIT PROGRAM 1002
  ELSE
    LET f_ok = TRUE
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
      CALL fgl_winmessage(%"function.lib.string.Fatal_Error", %"function.lib.string.ERROR_1003", "stop")
      EXIT PROGRAM 1003
    END IF
  END IF
  
  RETURN f_ok
  
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION hash_password(f_pass STRING) #****************************************#

  DEFINE
    salt STRING,
    hashed_pass STRING,
    f_ok SMALLINT
    
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

  DEFINE
    hashed_pass STRING,
    f_user_type STRING,
    f_ok SMALLINT

  LET f_ok = FALSE

  SELECT password,user_type INTO hashed_pass,f_user_type FROM local_accounts WHERE username = f_user

  IF hashed_pass IS NULL
  THEN
    LET f_ok = FALSE
  ELSE
    IF Security.BCrypt.CheckPassword(f_pass, hashed_pass) THEN
      LET f_ok = TRUE
      LET global_var.user = f_user
      LET global_var.user_type = f_user_type
      LET global_var.logged_in = CURRENT YEAR TO SECOND
    ELSE
      LET f_ok = FALSE
    END IF
  END IF

  RETURN f_ok
  
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION get_local_remember() #************************************************#

  {DEFINE
    f_remember SMALLINT,
    f_username LIKE local_accounts.username,
    f_ok SMALLINT

  CALL db_function_lib.openDB("local.db",FALSE)

  LET f_ok = FALSE

  SELECT remember, username INTO f_remember, f_username FROM local_remember WHERE 1  = 1

  IF f_remember IS NOT NULL
  THEN
    LET f_ok = TRUE
  ELSE
    CALL fgl_winmessage(%"function.lib.string.Fatal_Error", %"function.lib.string.ERROR_1004", "stop")
    EXIT PROGRAM 1004
  END IF

  IF f_remember = FALSE
  THEN
    LET f_username = ""
  END IF

  RETURN f_ok, f_remember, f_username}
    
END FUNCTION #*****************************************************************#
#
#
#
#
FUNCTION refresh_local_remember(f_username STRING,f_remember STRING) #*********#

    {DEFINE
        f_remember SMALLINT,
        f_username LIKE local_accounts.username,
        f_ok SMALLINT

    CALL db_function_lib.openDB("local.db",FALSE)

    LET f_ok = FALSE
    TRY
        UPDATE local_remember SET remember = f_remember, username = f_username, last_modified = CURRENT YEAR TO SECOND WHERE 1 = 1
    CATCH
        DISPLAY STATUS || " " || SQLERRMESSAGE
    END TRY

    IF sqlca.sqlcode <> 0
    THEN
        CALL fgl_winmessage(%"function.lib.string.Fatal_Error", %"function.lib.string.ERROR_1005", "stop")
        EXIT PROGRAM 1005
    ELSE
        LET f_ok = TRUE
    END IF

    RETURN f_ok}
    
END FUNCTION #*****************************************************************#