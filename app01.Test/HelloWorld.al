codeunit 50101 MyTests
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure TestSimples()
    begin
        Assert.IsTrue(true, 'Teste OK');
    end;
}
