*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

Library             RPA.Browser.Selenium    auto_close=${FALSE}
Library             RPA.HTTP
Library             RPA.Excel.Files
Library             RPA.PDF
Library             RPA.Tables
Library             RPA.FileSystem
Library             RPA.Archive
Library             RPA.Robocorp.Vault
Library             RPA.Dialogs
Library             Collections


*** Variables ***
${OUTPUTDIR}        Files/Receipts
${WEBSITE}          # Is set in the 'Get secret website Url' keyword as Suite Variable
${ORDERS}           # Is set in the 'Get orders data' Keyword as Suite Variable

${ORDERS_FILE}      Files/orders.csv    # For debugging, alternatively is set in 'Ask user for file location' keyword
${DEBUG}            False    # Simplifies logic for debugging purposes


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Ask user for file location
    Get secret website Url
    Open the robot order website
    Get orders data
    Fill in the form and get PDF
    Create ZIP archive and remove files
    [Teardown]    Close the browser


*** Keywords ***
Ask user for file location
    IF    ${DEBUG} == True    RETURN
    Add heading    Please provide location of 'orders.csv' file
    Add file input    name=orders_file    file_type=CSV files (*.csv)    source=../Robot/Files
    ${result}=    Run dialog
    Log    ${result.orders_file}[0]
    Log    ${ORDERS_FILE}
    Set Suite Variable    ${ORDERS_FILE}    ${result.orders_file}[0]

Get secret website Url
    ${secret}=    Get Secret    WEBSITE
    Set Suite Variable    ${WEBSITE}    ${secret}[URL]

Open the robot order website
    Open Available Browser    ${WEBSITE}

Close the browser
    Close Browser

Close modal
    Click Element    css:button[class='btn btn-danger']

Get orders data
    ${orders}=    Read table from CSV    ${ORDERS_FILE}    header=true
    Set Suite Variable    ${ORDERS}    ${orders}

Handle alert
    ${res}=    Does Page Contain Element    xpath://div[@role='alert' and @class='alert alert-danger']
    IF    ${res} == True
        Click Element    xpath://button[@id='order']
        Handle alert
    END

Create PDF
    [Arguments]    ${sequence}
    Wait Until Element Is Visible    xpath://img[@alt='Head']
    Wait Until Element Is Visible    xpath://img[@alt='Body']
    Wait Until Element Is Visible    xpath://img[@alt='Legs']
    ${image}=    Capture Element Screenshot
    ...    xpath://div[@id='robot-preview-image']
    ...    ${OUTPUTDIR}${/}robot-image.png
    Wait Until Element Is Visible    xpath://div[@id='receipt']
    ${html}=    Get Element Attribute    xpath://div[@id='receipt']    outerHTML
    ${html_with_image}=    Set Variable
    ...    ${html}<p><center><img src="${image}" width="300"></center></p>
    ${file_name}=    Set Variable    robot-receipt-${sequence}
    ${pdf_receipt}=    Html To Pdf    ${html_with_image}    ${OUTPUTDIR}${/}${file_name}.pdf
    Remove File    ${image}

Fill in the form and get PDF for one robot
    [Arguments]    ${order}
    Close modal
    Select From List By Value    xpath://select[@id='head']    ${order}[Head]
    Select Radio Button    body    ${order}[Body]
    Input Text    xpath://input[@placeholder='Enter the part number for the legs']    ${order}[Legs]
    Input Text    xpath://input[@id='address']    ${order}[Address]
    Click Element    xpath://button[@id='preview']
    Click Element    xpath://button[@id='order']
    Handle alert
    Create PDF    ${order}[Order number]
    Click Element    xpath://button[@id='order-another']

Fill in the form and get PDF
    FOR    ${order}    IN    @{ORDERS}
        Fill in the form and get PDF for one robot    ${order}
        IF    ${DEBUG} == True            BREAK
    END

Create ZIP archive and remove files
    Archive Folder With Zip    ${OUTPUTDIR}    ${OUTPUTDIR}${/}receipts.zip
    ${files}=    Find files    ${OUTPUTDIR}${/}*.pdf
    FOR    ${path}    IN    @{files}
        Remove File    ${path}
    END
