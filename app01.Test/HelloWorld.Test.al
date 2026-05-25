codeunit 50100 "Smoke Test"
{
    Subtype = Test;

    [Test]
    procedure TestIfPipelineWorks()
    begin
        Assert.IsTrue(true, 'Pipeline failed');
    end;
}
