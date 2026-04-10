report 50100 "PTSS Delete Wrong G/L Account"
{
    Caption = 'Delete Wrong G/L Account';
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    ProcessingOnly = true;

    Permissions = TableData 15 = rimd;

    dataset
    {
        dataitem(GLAccount; "G/L Account")
        {
            DataItemTableView = sorting("No.");
            RequestFilterFields = "No.";

            trigger OnAfterGetRecord()
            var
            begin
                if (GLAccount.Name = '') or (GLAccount.Name = GLAccount."No.") then begin
                    GLAccountTemp.Init();
                    GLAccountTemp := GLAccount;
                    GLAccountTemp.Insert(false);
                end;
            end;

            trigger OnPostDataItem()
            var
                lGLAccount: Record "G/L Account";
            begin
                GLAccountTemp.Reset();
                if GLAccountTemp.FindSet() then begin
                    repeat
                        lGLAccount.Reset();
                        lGLAccount.Get(GLAccountTemp."No.");
                        lGLAccount.Delete();
                    until GLAccountTemp.Next() = 0;
                end;
            end;
        }
    }

    var
        //Records//
        GLAccountTemp: Record "G/L Account" temporary;
}