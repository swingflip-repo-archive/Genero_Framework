# This is a kind of a botched non dynamic way of application internationalisation...
# This application should be ran via GDC and through GST. It will go through and extract 
# strings from 4gls and forms where applicable. It will then export these strings in to .str files
# which can be used to internationalise the application. RUNNING THIS APPLICATION WILL OVERWRITE ANY .STR FILES OF THE SAME NAME IN THE src/ FOLDER!

# This snippet is just an example of how it works, if you are wanting to make your application 
# multilingual then you should really write a more dynamic snippet tool or set up your GST to automatically
# generate the str files when compling.  

# 0 = good, 1 = bad

# Here is a useful note from the manual... 

{
    Follow these steps to internationalize your application.

    Identify the current character set used in your sources and make sure the application locale (LANG/LC_ALL) is set correctly.
    In .4gl sources, add a % prefix to the strings that must be localized (i.e. translated). For parameterized messages, replace concatenated strings by a SFMT() usage with %n placholders for variable message parts.
    In .per sources LAYOUT section, replace hard-coded form elements like text labels by static LABEL form items and define the TEXT attributes with a % prefix in the ATTRIBUTES section.
    In XML resources, add <LStr /> elements under the elements where text attributes must be localized.
    Extract the strings from the .4gl sources with fglcomp -m and use fglform -m for .per sources.
    Organize the generated .str source string files (identify duplicated strings and put them in a common file).
    At this point, the string identifiers (on the left) are the same as the string texts (on the right). These string identifiers can be used as is, or can be changed to clear ASCII identifiers such as "customer.list.title". Using simple identifiers allows you to distinguish strings depending on the context and use ASCII encoding for your sources. Keeping string identifiers with the original text requires no source changes (except adding the % prefix), but makes sources dependent to a locale: If you want to support multiple languages, you must use UTF-8 in sources and at runtime.
    When using simple ASCII identifiers, replace original strings with the new string identifiers. Strings to be replaced can be located by their % prefix. You can, for example, use a script with an utility like the sed UNIX™ command to read the .str files and apply the changes automatically.
    Recompile the .4gl and .per sources (when using simple ASCII strings identifiers, sources should be full ASCII now).
    Compile the .str files in the locale used by these files,
    Setup FGLPROFILE fglrun.localization.* entries, to let fglrun find the string resource files.
    Run your programs to check whether the application displays the text properly.
    Copy the existing .str files, and translate the string text into another language (make sure the locale is correct).
    Compile the new .str files, and copy the .42s files into another distribution directory, defined with the FGLRESOURCEPATH environment variable.
    Run again your programs, to check that texts and labels of the other language are displayed.
    Next changes to the .per and .4gl source files should be done in the ASCII locale, and .str string files must be edited with their specific locale.
}

# Final note, please note if you are using localized strings with parameters, please use SFMT() instead of the prefix behind each string method (like I did!)

MAIN
    DEFINE
        cmd STRING,
        status INTEGER

    DISPLAY "--------------------------------------------------------------"
    
    --MAINS AND LIBRARIES (fglcomp)
    LET cmd = "fglcomp -m ../src/main.4gl > ../src/main_strings.str"
    
    RUN cmd RETURNING status

    DISPLAY "Main String Extraction Status: " || status

    LET cmd = "fglcomp -m ../src/function_lib.4gl > ../src/function_lib_strings.str"
    
    RUN cmd RETURNING status

    DISPLAY "Function Library String Extraction Status: " || status

    --FORMS (fglform)
    LET cmd = "fglform -m ../src/admin.per > ../src/admin_per.str"
    
    RUN cmd RETURNING status

    DISPLAY "Admin Form Extraction String Status: " || status

    LET cmd = "fglform -m ../src/connection.per > ../src/connection_per.str"
    
    RUN cmd RETURNING status

    DISPLAY "Interaction Demo Form Extraction String Status: " || status

    LET cmd = "fglform -m ../src/interact.per > ../src/interact_per.str"
    
    RUN cmd RETURNING status

    DISPLAY "Connection Form Extraction String Status: " || status

    LET cmd = "fglform -m ../src/main.per > ../src/main_per.str"
    
    RUN cmd RETURNING status

    DISPLAY "Main Form Extraction String Status: " || status

    LET cmd = "fglform -m ../src/photo.per > ../src/photo_per.str"
    
    RUN cmd RETURNING status

    DISPLAY "Photo Form Extraction String Status: " || status

    DISPLAY "--------------------------------------------------------------"    
    
END MAIN