namespace System.Test.Tooling;

codeunit 50116 "BCPT Sleep 1s"
{
    trigger OnRun();
    begin
        Sleep(1000);
    end;
}
