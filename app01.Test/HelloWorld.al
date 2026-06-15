codeunit 50110 CustomerListTests
{
    Subtype = Test;

    [Test]
    [HandlerFunctions('DisplayMessageHandler')]
    procedure CheckMessageDisplayed()
    var
        CustomerList: TestPage "Customer List";
    begin
        CustomerList.OpenView();
        CustomerList.Close();
        if (not MessageDisplayed) then
            Error('The page was not displayed.');
    end;

    [Test]
    [HandlerFunctions('InfoMessageHandler')]
    procedure CheckMessageInformation()
    var
        CustomerList: TestPage "Customer List";
    begin
        CustomerList.OpenView();
        CustomerList.Close();
        if (not MessageInformation) then
            Error('The message was wrong.');
    end;

    [Test]
    [HandlerFunctions('DisplayMessageHandler')]
    procedure FieldNameIsVisibleOnPage()
    var
        CustomerList: TestPage "Customer List";
    begin
        CustomerList.OpenView();
        if not CustomerList.Name.Visible then
            Error('Field Name is not visible');
        CustomerList.Close();
    end;

    [MessageHandler]
    procedure DisplayMessageHandler(MessageText: Text[1024])
    begin
        MessageDisplayed := true;
    end;

    [MessageHandler]
    procedure InfoMessageHandler(MessageText: Text[1024])
    begin
        if MessageText = 'App published: Hello world!' then
            MessageInformation := true;
    end;




    var
        MessageDisplayed: Boolean;
        MessageInformation: Boolean;
}
