IMPORT util
GLOBALS "../src/globals.4gl"

MAIN
    DEFINE #These are very useful module variables to have defined!
        m_ok SMALLINT,
        m_local_images_available DYNAMIC ARRAY OF CHAR(2),
        m_JSON STRING,
        m_cmd STRING,
        m_status STRING

    #******************************************************************************#
    # HERE IS WHERE YOU CONFIGURE GOBAL SWITCHES FOR THE APPLICATION
    # ADJUST THESE AS YOU SEEM FIT. BELOW IS A LIST OF OPTIONS IN ORDER:
    #        global_config.g_application_database_ver INTEGER,               #Application Database Version (This is useful to force database additions to pre-existing db instances)
    #        global_config.g_enable_splash SMALLINT,                         #Open splashscreen when opening the application.
    #        global_config.g_splash_duration INTEGER,                        #Splashscreen duration (seconds) global_config.g_enable_splash needs to be enabled!
    #        global_config.g_enable_login SMALLINT                           #Boot in to login menu or straight into application (open_application())
    #        global_config.g_splash_width STRING,                            #Login menu splash width when not in mobile
    #        global_config.g_splash_height STRING,                           #Login menu splash height when not in mobile
    #        global_config.g_enable_geolocation SMALLINT,                    #Toggle to enable geolocation
    #        global_config.g_enable_mobile_title SMALLINT,                   #Toggle application title on mobile
    #        global_config.g_local_stat_limit INTEGER,                       #Number of max local stat records before pruning
    #        global.g_online_pinglobal_config.g_URL STRING,                         #URL of public site to test internet connectivity (i.e. http://www.google.com) 
    #        global_config.g_enable_timed_connect SMALLINT,                  #Enable timed connectivity checks
    #        global_config.g_timed_checks_time INTEGER                       #Time in seconds before checking connectivity (global_config.g_enable_timed_connect has to be enabled)
    #        global_config.g_date_format STRING                              #Datetime format. i.e.  "%d/%m/%Y %H:%M"
    #        global_config.g_image_dest STRING                               #Webserver destination for image payloads. i.e. "Webservice_1" (Not used as of yet)
    #        global_config.g_ws_end_point STRING,                            #The webservice end point. 
    #        global_config.g_enable_timed_image_upload SMALLINT,             #Enable timed image queue uploads (Could have a performance impact!)
    #        global_config.g_local_images_available DYNAMIC ARRAY OF CHAR(2) #Available localisations for images.
    #        global_config.g_default_language STRING,                        #The default language used within the application (i.e. EN)
    # Here are globals not included in initialize_globals function due to sheer size of the arguement data...
    #        global_config.g_client_key STRING,                              #Unique Client key for webservice purposes

        #List the localisations availble for images and wc here so we can change the images depending on locale...
        LET m_local_images_available[1] = "EN"
        LET m_local_images_available[2] = "FR"
        
        CALL load_globals(1,                                  #global_config.g_application_database_ver INTEGER
                          TRUE,                               #global_config.g_enable_splash SMALLINT
                          5,                                  #global_config.g_splash_duration INTEGER
                          TRUE,                               #global_config.g_enable_login SMALLINT
                          "500px",                            #global_config.g_splash_width STRING
                          "281px",                            #global_config.g_splash_height STRING
                          FALSE,                              #global_config.g_enable_geolocation SMALLINT
                          FALSE,                              #global_config.g_enable_mobile_title SMALLINT
                          100,                                #global_config.g_local_stat_limit INTEGER
                          "http://www.google.com",            #global.g_online_pinglobal_config.g_URL STRING
                          TRUE,                               #global_config.g_enable_timed_connect SMALLINT
                          10,                                 #global_config.g_timed_checks_time INTEGER
                          "%d/%m/%Y %H:%M",                   #global_config.g_date_format STRING
                          "webserver1",                       #global_config.g_image_dest STRING  
                          "http://www.ryanhamlin.co.uk/ws",   #global_config.g_ws_end_point STRING
                          TRUE,                               #global_config.g_enable_timed_image_upload SMALLINT
                          "EN",                               #global_config.g_default_language CHAR(2)
                          m_local_images_available)           #global_config.g_local_images_available DYNAMIC ARRAY OF CHAR(2)
            RETURNING m_ok
            
        LET global_config.g_client_key = "znbi58mCGZXSBNkJ5GouFuKPLqByReHvtrGj7aXXuJmHGFr89Xp7uCqDcVCv"      #global_config.g_client_key STRING

    #******************************************************************************#

        
        LET m_JSON = util.JSON.stringifyOmitNulls(global)
        LET m_JSON = util.JSON.format(m_JSON)

        #We would have to do a lot of rejigging to get this to echo to file with format intact. Therefore it is a lot easier
        #just to copy the standard output into a file.
        {LET m_cmd = "echo " || m_JSON || " > ../config/GGAT.config"
        DISPLAY m_cmd
        RUN m_cmd RETURNING m_status}

        DISPLAY m_JSON

END MAIN

FUNCTION load_globals(f_application_database_ver, f_enable_splash, f_splash_duration, f_enable_login,f_splash_w,f_splash_h,f_geo,f_mobile_title,f_local_limit,f_online_ping_URL,
                      f_enable_timed_connect,f_timed_connect_time,f_date_format,f_image_dest, f_ws_end_point,
                      f_enable_timed_image_upload, f_default_language, f_local_images_available) #Set up global variables
    DEFINE
        f_ok SMALLINT,
        f_enable_login SMALLINT,
        f_splash_w STRING,
        f_splash_h STRING,
        f_geo SMALLINT,
        f_mobile_title SMALLINT,
        f_local_limit INTEGER,
        f_online_ping_URL STRING,
        f_enable_timed_connect SMALLINT,
        f_timed_connect_time INTEGER,
        f_date_format STRING,
        f_image_dest STRING,
        f_enable_timed_image_upload SMALLINT,
        f_application_database_ver INTEGER,
        f_enable_splash SMALLINT,
        f_splash_duration INTEGER,
        f_ws_end_point STRING,
        f_default_language CHAR(2),
        f_local_images_available DYNAMIC ARRAY OF CHAR(2)

    LET f_ok = FALSE

    LET global_config.g_enable_splash = f_enable_splash
    LET global_config.g_splash_duration = f_splash_duration
    LET global_config.g_enable_login = f_enable_login
    LET global_config.g_splash_width = f_splash_w
    LET global_config.g_splash_height = f_splash_h
    LET global_config.g_enable_geolocation = f_geo
    LET global_config.g_enable_mobile_title = f_mobile_title
    LET global_config.g_local_stat_limit = f_local_limit
    LET global_config.g_online_ping_URL = f_online_ping_URL
    LET global_config.g_enable_timed_connect = f_enable_timed_connect
    LET global_config.g_timed_checks_time = f_timed_connect_time
    LET global_config.g_date_format = f_date_format
    LET global_config.g_image_dest = f_image_dest
    LET global_config.g_enable_timed_image_upload = f_enable_timed_image_upload
    LET global_config.g_application_database_ver = f_application_database_ver
    LET global_config.g_ws_end_point = f_ws_end_point
    LET global_config.g_default_language = f_default_language
    LET global_config.g_local_images_available = f_local_images_available
    
    LET f_ok = TRUE
        
    RETURN f_ok
END FUNCTION