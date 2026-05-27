codeunit 50101 MyTests
{
    Subtype = Test;

    [Test]
    procedure TestSimples()
    begin
        Assert.IsTrue(true, 'Teste OK');
    end;
}
