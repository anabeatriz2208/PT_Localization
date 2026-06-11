codeunit 50110 CustomerListTests
{
    Subtype = Test;

    [Test]
    procedure AbrirPagina()
    var
        CustomerList: TestPage "Customer List";
    begin
        CustomerList.OpenView();
        CustomerList.Close();
    end;
}
