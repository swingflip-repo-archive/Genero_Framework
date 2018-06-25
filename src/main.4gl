################################################################################
# START OF APPLICATION
# Written by Ryan Hamlin - 2018. (rhamlin@4js.com)
################################################################################
IMPORT os
IMPORT util
        
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
      online_pingURL STRING,                          #URL of public site to test internet connectivity (i.e. http://www.google.com) 
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
    m_require_app_reload SMALLINT
  
MAIN ###########################################################################

  DISPLAY "App Start - " || TIME( CURRENT )
  
  #Detect user's locale and set language accordingly
  CALL ui.Interface.frontCall("standard", "feInfo", "userPreferredLang", global_var.info.locale)

  LET global_var.language = global_var.info.locale

  CALL load_localisation(global_var.info.locale,TRUE)
      RETURNING m_require_app_reload

  CALL initialise_app()

  DISPLAY "App Finish - " || TIME( CURRENT )

END MAIN #######################################################################

FUNCTION load_localisation(f_locale STRING, f_pre_window SMALLINT) #***********#
  DEFINE
    f_localisation_path STRING,
    f_stringbuffer base.StringBuffer,
    f_require_reload SMALLINT
      
  LET f_require_reload = FALSE
  
  LET f_stringbuffer = base.StringBuffer.create()
  CALL f_stringbuffer.append(f_locale)
  LET global_var.language_short = f_stringbuffer.subString(1,2)

  #Load language pack if exists otherwise stick with the default pack

  IF os.Path.exists(os.Path.join(base.Application.getProgramDir(), f_locale)) #i.e. en_GB or en_US
  THEN
    LET global_var.language = f_locale
    LET f_localisation_path = os.Path.join(base.Application.getProgramDir(), global_var.language)
    DISPLAY f_localisation_path
    CALL base.Application.reloadResources(f_localisation_path)
    LET f_require_reload = TRUE
  ELSE
    LET f_locale = f_stringbuffer.subString(1,2)
    IF os.Path.exists(os.Path.join(base.Application.getProgramDir(), f_locale)) #i.e. en or fr or de
    THEN
      LET global_var.language = f_locale
      LET f_localisation_path = os.Path.join(base.Application.getProgramDir(), global_var.language)
      DISPLAY f_localisation_path
      CALL base.Application.reloadResources(f_localisation_path)
      LET f_require_reload = TRUE
    END IF
  END IF

  IF f_pre_window = TRUE
  THEN
    LET f_require_reload = FALSE #Even if we have changed the local language, we don't need to reload window because pre window
  END IF

  RETURN f_require_reload
    
END FUNCTION #*****************************************************************#