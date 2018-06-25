IMPORT SECURITY
IMPORT com
IMPORT util
IMPORT os
IMPORT FGL main
#SCHEMA local_db

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
        #If you get to this point you have done something drastically wrong...
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
    
END FUNCTION