################################################################################
# START OF APPLICATION
# Written by Ryan Hamlin - 2018. (rhamlin@4js.com)
################################################################################
IMPORT os
IMPORT util
IMPORT FGL function_lib

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