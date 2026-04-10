report 50009 "PTSS Taxonomy to GLAccount"
{
    Caption = 'Give GLAccount a Taxonomy code';
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    ProcessingOnly = true;

    Permissions = TableData 15 = rimd;

    dataset
    {
        dataitem(GLAccount; "G/L Account")
        {
            trigger OnAfterGetRecord()
            var
                CompanyInfo: Record "Company Information";
            begin
                If CompanyInfo."PTSS Taxonomy Reference" <> CompanyInfo."PTSS Taxonomy Reference"::"S - SNC Base" then begin
                    CompanyInfo."PTSS Taxonomy Reference" := CompanyInfo."PTSS Taxonomy Reference"::"S - SNC Base";
                    CompanyInfo.Modify(true);
                end;

                if not (GLAccount."PTSS Taxonomy Code" IN [1 .. 647]) then begin
                    if GLAccount."Account Type" = GLAccount."Account Type"::Posting then begin
                        GLAccountTemp.Init();
                        GLAccountTemp := GLAccount;
                        GLAccountTemp.Insert(false);
                    end;
                end;

                if (GLAccount."Income/Balance" = GLAccount."Income/Balance"::"Income Statement") then begin
                    //if GLAccount."Account Type" = GLAccount."Account Type"::Total then begin
                    GLAccountTemp2.Init();
                    GLAccountTemp2 := GLAccount;
                    GLAccountTemp2.Insert(false);
                    //end;
                end;
            end;

            trigger OnPostDataItem()
            var
                lGLAccount: Record "G/L Account";
                lTaxonomyCode: Record "PTSS Taxonomy Codes";
            begin
                GLAccountTemp.Reset();
                if GLAccountTemp.FindSet() then begin
                    repeat
                        lGLAccount.Reset();
                        lGLAccount.Get(GLAccountTemp."No.");
                        lGLAccount.Validate("PTSS Taxonomy Code", 1);
                        if lGLAccount."No." <> '111' then begin
                            lGLAccount.Validate("PTSS Income Stmt. Bal. Acc.", '111');
                        end;
                        lGLAccount.Modify(true);
                    until GLAccountTemp.Next() = 0;
                end;
                GLAccountTemp2.Reset();
                if GLAccountTemp2.FindSet() then begin
                    repeat
                        lGLAccount.Reset();
                        lGLAccount.Get(GLAccountTemp2."No.");
                        lGLAccount.Validate("PTSS Income Stmt. Bal. Acc.", '111');
                        lGLAccount.Modify(true);
                    until GLAccountTemp2.Next() = 0;
                end;
            end;
        }
    }

    var
        //Records//
        //GLAccountTemp - Se o Código de taxonomia da conta tipo "Posting" estiver vazio
        //GLAccountTemp2 - Se o "Income/Balance" for "Income Statement" atribuir na Conta regularização um valor
        GLAccountTemp, GLAccountTemp2 : Record "G/L Account" temporary;
}