################################################################################
# APPLICATION MAIN
# Written by Ryan Hamlin - 2018. (rhamlin@4js.com)
################################################################################
IMPORT os
IMPORT util
IMPORT FGL function_lib
IMPORT FGL fgldialog

  PRIVATE DEFINE #Common use Module Variables
    TERMINATE SMALLINT,
    m_string_tokenizer base.StringTokenizer,
    m_window ui.Window,
    m_form ui.Form,
    m_dom_node1 om.DomNode,
    m_index INTEGER,
    m_ok SMALLINT,
    m_status STRING,
    f_current_DT DATETIME YEAR TO SECOND

  PRIVATE DEFINE
    m_username STRING,
    m_password STRING,
    m_remember STRING,
    m_image STRING
    
FUNCTION initialise_app() #****************************************************#

  #Grab deployment data...
  CALL ui.interface.getFrontEndName() RETURNING global_var.info.deployment_type
  CALL ui.interface.frontCall("standard", "feInfo", "osType", global_var.info.os_type)
  CALL ui.Interface.frontCall("standard", "feInfo", "ip", global_var.info.ip)
  CALL ui.Interface.frontCall("standard", "feInfo", "deviceId", global_var.info.device_name)    
  CALL ui.Interface.frontCall("standard", "feInfo", "screenResolution", global_var.info.resolution)

  #Set global application details here...
  LET global_var.application_title =%"main.string.App_Title"
  LET global_var.application_version =%"main.string.App_Version"
  LET global_var.title =  global_var.application_title || " " || global_var.application_version
        
  #BREAKPOINT #Uncomment to step through application
        
  LET m_string_tokenizer = base.StringTokenizer.create(global_var.info.resolution,"x")

  WHILE m_string_tokenizer.hasMoreTokens()
    IF m_index = 1
    THEN
        LET global_var.info.resolution_x = m_string_tokenizer.nextToken() || "px"
    ELSE
        LET global_var.info.resolution_y = m_string_tokenizer.nextToken() || "px"
    END IF
    LET m_index = m_index + 1
  END WHILE

  IF global_config.debug_level >= 1 
  THEN
    CALL function_lib.sync_config("app.config",TRUE)
  ELSE
    CALL function_lib.sync_config("app.config",FALSE)
  END IF
  CALL function_lib.initialize_publics()
    RETURNING m_ok

  IF global_config.debug_level >= 2 
  THEN
    DISPLAY "\nStarting up " || global_var.application_title || " " || global_var.application_version || "..."
    
    IF global_var.info.deployment_type <> "GMA" AND global_var.info.deployment_type <> "GMI"
    THEN
      DISPLAY "--Deployment Data--\n" ||
              "Deployment Type: " || global_var.info.deployment_type || "\n" ||
              "OS Type: " || global_var.info.os_type || "\n" ||
              "User Locale: " || global_var.info.locale || "\n" ||
              "Device IP: " || global_var.info.ip || "\n" ||
              "Resolution: " || global_var.info.resolution || "\n" ||
              "-------------------\n"
    ELSE
      DISPLAY "--Deployment Data--\n" ||
              "Deployment Type: " || global_var.info.deployment_type || "\n" ||
              "OS Type: " || global_var.info.os_type || "\n" ||
              "User Locale: " || global_var.info.locale || "\n" ||
              "Device IP: " || global_var.info.ip || "\n" ||
              "Device ID: " || global_var.info.device_name || "\n" ||
              "Resolution: " || global_var.info.resolution || "\n" ||
              "-------------------\n"
    END IF
  END IF
          
  IF m_ok = FALSE
  THEN
    CALL fgl_winMessage(global_var.title, %"main.string.ERROR_1001", "stop")
    EXIT PROGRAM 1001
  END IF

  IF global_config.enable_geolocation = TRUE
  THEN
    IF global_var.info.deployment_type <> "GMA" AND global_var.info.deployment_type <> "GMI"
    THEN
      DISPLAY "****************************************************************************************\n" ||
              "WARNING: Set up error, track geolocation is enabled and you are not deploying in mobile.\n" ||
              "****************************************************************************************\n"
    ELSE
      CALL ui.Interface.frontCall("mobile", "getGeolocation", [], [global_var.info.geo_status, global_var.info.geo_lat, global_var.info.geo_lon])
      IF global_config.debug_level >= 1
      THEN
        DISPLAY "--Geolocation Tracking Enabled!--"
        DISPLAY "Geolocation Tracking Status: " || global_var.info.geo_status
        IF global_var.info.geo_status = "ok"
        THEN
          DISPLAY "Latitude: " || global_var.info.geo_lat
          DISPLAY "Longitude: " || global_var.info.geo_lon
        END IF
        DISPLAY "---------------------------------\n"
      END IF
    END IF
  END IF

  CALL function_lib.test_connectivity(global_var.info.deployment_type)
  CALL function_lib.capture_local_stats(global_var.info.*)
    RETURNING m_ok

  CLOSE WINDOW SCREEN #Just incase

  IF global_config.enable_splash = TRUE AND global_config.splash_duration > 0
  THEN
    CALL run_splash_screen()
  ELSE
    IF global_config.enable_login = TRUE
    THEN
      CALL login_screen() 
    ELSE
      CALL open_application()
    END IF
  END IF
    
END FUNCTION

################################################################################

################################################################################
#Individual window/form functions...
################################################################################

FUNCTION run_splash_screen() #Application Splashscreen window function

    DEFINE
        f_result STRING
        
    OPEN WINDOW w WITH FORM "splash_screen"

    INITIALIZE f_result TO NULL
    TRY 
        CALL ui.Interface.frontCall("webcomponent","call",["formonly.splashwc","setLocale",global_var.language_short],[f_result])
    CATCH
        ERROR err_get(status)
        DISPLAY err_get(status)
    END TRY
    
    LET TERMINATE = FALSE
    INITIALIZE global_var.instruction TO NULL
    LET m_window = ui.Window.getCurrent()

    IF global_var.info.deployment_type <> "GMA" AND global_var.info.deployment_type <> "GMI"
    THEN
        CALL m_window.setText(global_var.title)
    ELSE
        IF global_config.enable_mobile_title = FALSE
        THEN
            CALL m_window.setText("")
        ELSE
            CALL m_window.setText(global_var.title)
        END IF
    END IF

    LET TERMINATE = FALSE

    WHILE TERMINATE = FALSE
        MENU

        ON TIMER global_config.splash_duration
            LET TERMINATE = TRUE
            EXIT MENU

        BEFORE MENU
            CALL DIALOG.setActionHidden("close",1)

        ON ACTION CLOSE
            LET TERMINATE = TRUE
            EXIT MENU
              
        END MENU
    END WHILE

    IF global_config.enable_login = TRUE
    THEN
        CLOSE WINDOW w
        CALL login_screen() 
    ELSE
        CLOSE WINDOW w
        CALL open_application()
    END IF

END FUNCTION
#
#
#
#
FUNCTION login_screen() #Local Login window function

    DEFINE
        f_install_type INTEGER,
        f_username STRING,
        f_password STRING,
        f_confirm_password STRING,
        f_user_type STRING,
        f_email STRING,
        f_telephone STRING,
        f_hashed_string STRING
            
        
    CALL check_new_install()
        RETURNING f_install_type

    IF f_install_type == 2
    THEN
        EXIT PROGRAM 9999
    END IF

    IF f_install_type == 1 #Fresh Install... Open new user create before running
    THEN
        OPEN WINDOW w WITH FORM "tool_new_install"

        LET TERMINATE = FALSE
        INITIALIZE global_var.instruction TO NULL
        LET m_window = ui.Window.getCurrent()

        IF global_var.info.deployment_type <> "GMA" AND global_var.info.deployment_type <> "GMI"
        THEN
            CALL m_window.setText(global_var.title)
        ELSE
            IF global_config.enable_mobile_title = FALSE
            THEN
                CALL m_window.setText("")
            ELSE
                CALL m_window.setText(global_var.title)
            END IF
        END IF
        
        INPUT f_username, f_password, f_confirm_password, f_user_type, f_email, f_telephone
            FROM username, password, confirm_password, user_type, email, telephone ATTRIBUTE(UNBUFFERED)
            
            BEFORE INPUT
                CALL DIALOG.setActionHidden("accept",1)
                CALL DIALOG.setActionHidden("cancel",1)

            ON CHANGE username
                LET f_username = downshift(f_username)

            ON ACTION bt_submit
                ACCEPT INPUT

            ON ACTION CLOSE
                EXIT INPUT
                
            AFTER INPUT
                #Validate Input
                CALL validate_input_data(f_username, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, "") RETURNING f_username, m_ok, m_status 
                IF m_ok = FALSE
                THEN
                    CALL fgl_winmessage(" ",%"tool.string.Bad_Username","stop")
                    NEXT FIELD username
                END IF
                CALL validate_input_data(f_password, FALSE, TRUE, TRUE, TRUE, TRUE, FALSE, "") RETURNING f_password, m_ok, m_status 
                IF m_ok = FALSE
                THEN
                    CALL fgl_winmessage(" ",%"tool.string.Bad_Password","stop")
                    NEXT FIELD password
                END IF
                CALL validate_input_data(f_confirm_password, FALSE, TRUE, TRUE, TRUE, TRUE, FALSE, "") RETURNING f_confirm_password, m_ok, m_status 
                IF m_ok = FALSE
                THEN
                    CALL fgl_winmessage(" ",%"tool.string.Bad_Password","stop")
                    NEXT FIELD password
                END IF
                IF f_password != f_confirm_password 
                THEN
                    CALL fgl_winmessage(" ",%"tool.string.Mismatch_Password","stop")
                    INITIALIZE f_confirm_password TO NULL
                    NEXT FIELD confirm_password
                END IF
                IF f_user_type IS NULL
                THEN
                    CALL fgl_winmessage(" ",%"tool.string.No_User_Type","stop")
                    NEXT FIELD user_type
                END IF      
                CALL validate_input_data(f_email, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, "EMAIL") RETURNING f_email, m_ok, m_status 
                IF m_ok = FALSE
                THEN
                    CALL fgl_winmessage(" ",%"tool.string.Bad_Email","stop")
                    NEXT FIELD email
                END IF
                CALL validate_input_data(f_telephone, TRUE, FALSE, FALSE, TRUE, FALSE, TRUE, "") RETURNING f_telephone, m_ok, m_status 
                IF m_ok = FALSE
                THEN
                    CALL fgl_winmessage(" ",%"tool.string.Bad_Telephone","stop")
                    NEXT FIELD telephone
                END IF

                SELECT COUNT(*) INTO m_index FROM local_accounts WHERE username = f_username
                IF m_index > 0 
                THEN
                    CALL fgl_winmessage(" ",%"tool.string.Username_Exists","stop")
                    NEXT FIELD username    
                END IF
                LET f_username = f_username.toLowerCase()
                CALL hash_password(f_password) RETURNING m_ok, f_hashed_string
                 
                TRY
                    INSERT INTO local_accounts VALUES(NULL,f_username,f_hashed_string,f_email,f_telephone,NULL,f_user_type)
                CATCH
                    CALL fgl_winmessage("User Create Tool","ERROR: could not create user in the database -" || sqlca.sqlcode,"stop")
                    EXIT PROGRAM 999
                END TRY

                IF f_email IS NULL THEN LET f_email = " " END IF
                IF f_telephone IS NULL THEN LET f_telephone = " " END IF
                                                         
                CALL fgl_winmessage(%"tool.string.Create_User",%"tool.string.Status" || ": " || "OK" || "\n" ||
                                                               %"tool.string.Username" || ": " || f_username || "\n" ||
                                                               %"tool.string.Password" || ": " || f_password || "\n" ||
                                                               %"tool.string.Hashed_Password" || ": " || f_hashed_string || "\n" ||
                                                               %"tool.string.User_Type" || ": " || f_user_type || "\n" ||
                                                               %"tool.string.Email" || ": " || f_email || "\n" ||
                                                               %"tool.string.Telephone" || ": " || f_telephone, "information") 

                LET global_var.instruction = "proceed"
        END INPUT

        CASE global_var.instruction #Depending on the instruction, we load up new windows/forms within the application whithout unloading.
            WHEN "proceed"
                CLOSE WINDOW w
                CALL login_screen()
            WHEN "go_back"
                CLOSE WINDOW w
                CALL admin_tools()
            WHEN "logout"
                INITIALIZE global_var.user TO NULL
                INITIALIZE global_var.logged_in TO NULL
                DISPLAY "Logged out successfully!"
                CLOSE WINDOW w
                CALL login_screen()
            OTHERWISE
                CALL ui.Interface.refresh()
                CALL close_app()
        END CASE
    ELSE
        OPEN WINDOW w WITH FORM "main"
        
        #Initialize window specific variables
      
        LET TERMINATE = FALSE
        INITIALIZE global_var.instruction TO NULL
        LET m_window = ui.Window.getCurrent()
        LET m_dom_node1 = m_window.findNode("Image","splash")

        IF global_var.info.deployment_type <> "GMA" AND global_var.info.deployment_type <> "GMI"
        THEN
            CALL m_window.setText(global_var.title)
        ELSE
            IF global_config.enable_mobile_title = FALSE
            THEN
                CALL m_window.setText("")
            ELSE
                CALL m_window.setText(global_var.title)
            END IF
        END IF

        #We need to adjust the image so it appears correctly in GDC,GBC,GMA and GMI

        #Set the login splash size if we are running in GDC
        IF global_var.info.deployment_type = "GDC"
        THEN
            CALL m_dom_node1.setAttribute("sizePolicy","dynamic")
            CALL m_dom_node1.setAttribute("width",global_config.splash_width)
            CALL m_dom_node1.setAttribute("height",global_config.splash_height)
        END IF

        #Set the login screen image to stretch both in GBC
        IF global_var.info.deployment_type = "GBC" 
        THEN
            CALL m_dom_node1.setAttribute("stretch","both")
        END IF

        #Set the login screen image to the corresponding language loaded
        CALL set_localised_image("splash")
            RETURNING m_image
        CALL m_dom_node1.setAttribute("image",m_image)

        INPUT m_username, m_password, m_remember FROM username, password, remember ATTRIBUTE(UNBUFFERED)

            ON TIMER global_config.timed_checks_time
                CALL connection_test()
                CALL timed_upload_queue_data()
            
            BEFORE INPUT
                CALL connection_test()
                LET m_form = m_window.getForm()
                CALL DIALOG.setActionHidden("accept",1)
                CALL DIALOG.setActionHidden("cancel",1)
                CALL get_local_remember()
                    RETURNING m_ok, m_remember, m_username

            ON CHANGE username
                LET m_username = m_username.toLowerCase()
                CALL refresh_local_remember(m_username, m_remember)
                    RETURNING m_ok

            ON CHANGE remember
                CALL refresh_local_remember(m_username, m_remember)
                    RETURNING m_ok

            ON CHANGE password
                CALL refresh_local_remember(m_username, m_remember)
                    RETURNING m_ok

            ON ACTION bt_login
                ACCEPT INPUT

            ON ACTION CLOSE
                EXIT INPUT
                
            AFTER INPUT
              #Validate Input
              CALL validate_input_data(m_username, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, "") RETURNING m_username, m_ok, m_status 
              IF m_ok = FALSE
              THEN
                  CALL fgl_winmessage(" ",%"main.string.Bad_Username","stop")
                  NEXT FIELD username
              END IF
              CALL validate_input_data(m_password, FALSE, TRUE, TRUE, TRUE, TRUE, FALSE, "") RETURNING m_password, m_ok, m_status 
              IF m_ok = FALSE
              THEN
                  CALL fgl_winmessage(" ",%"main.string.Bad_Password","stop")
                  NEXT FIELD password
              END IF
              #Check Password
              CALL check_password(m_username,m_password) RETURNING m_ok
              INITIALIZE m_password TO NULL #Clean down the plain text password
              
              IF m_ok = TRUE
              THEN
                  LET global_var.instruction = "connection"
                  EXIT INPUT
              ELSE
                  CALL fgl_winmessage(" ",%"main.string.Incorrect_Username", "information")
                  NEXT FIELD password
              END IF
                
        END INPUT

        CASE global_var.instruction #Depending on the instruction, we load up new windows/forms within the application whithout unloading.
            WHEN "connection"
                CLOSE WINDOW w
                CALL open_application()
            OTHERWISE
                CALL ui.Interface.refresh()
                CALL close_app()
        END CASE
    END IF
END FUNCTION
#
#
#
#
FUNCTION open_application() #First Application window function (Demo purposes loads 'connection' form)

   

END FUNCTION

################################################################################

################################################################################
#Module Functions...
################################################################################

FUNCTION connection_test() #Test online connectivity, call this whenever opening new window!
    IF global_config.enable_timed_connect = TRUE
    THEN
        CALL test_connectivity(global_var.info.deployment_type)
        IF global_var.online = "NONE" AND global_var.info.deployment_type = "GMA" OR global_var.online = "NONE" AND global_var.info.deployment_type = "GMI"
        THEN
            IF global_config.enable_mobile_title = FALSE
            THEN
                CALL m_window.setText(%"main.string.Working_Offline")
            ELSE
                CALL m_window.setText(%"main.string.Working_Offline" || global_var.title)
            END IF
        ELSE
            IF global_config.enable_mobile_title = FALSE
            THEN
                CALL m_window.setText("")
            ELSE
                CALL m_window.setText(global_var.title)
            END IF
        END IF
    END IF
END FUNCTION
#
#
#
#
FUNCTION update_connection_image(f_image) #Used to update connection image within the demo about page

    DEFINE
        f_image STRING
    
    LET m_form = m_window.getForm()
    IF global_var.online = "NONE"
    THEN
        CALL m_form.setElementImage(f_image,"disconnected")
        DISPLAY %"main.string.Services_Disconnected" TO connected
    ELSE
        CALL m_form.setElementImage(f_image,"connected")
        DISPLAY %"main.string.Services_Connected" TO connected
    END IF 
END FUNCTION

################################################################################