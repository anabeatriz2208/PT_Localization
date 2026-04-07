codeunit 50095 "PTSS Tester Helper"
{
    local procedure FillCompanyBasicInfo()
    var
        CompanyInfo: Record "Company Information";
        PostCode: Record "Post Code";
        CountryRegion: Record "Country/Region";
        Currency: Record Currency;
        GLSetup: Record "General Ledger Setup";
    begin
        CompanyInfo.Get;
        CompanyInfo.Name := LibUti.GenerateRandomcode(CompanyInfo.FieldNo(Name), Database::"Company Information");
        CompanyInfo.Address := LibUti.GenerateRandomcode(CompanyInfo.FieldNo(Address), Database::"Company Information");
        CompanyInfo.City := LibUti.GenerateRandomcode(CompanyInfo.FieldNo(City), Database::"Company Information");
        SSLib.CreatePostCode(PostCode);
        CompanyInfo."Post Code" := PostCode.Code;
        SSLib.CreatePTCountryRegion(CountryRegion);
        CompanyInfo."Country/Region Code" := CountryRegion.Code;
        CompanyInfo."VAT Registration No." := Format(LibRandom.RandIntInRange(100000000, 999999999));
        CompanyInfo.Modify;

        SSLib.CreateCurrency(Currency);
        GLSetup.get();
        GLSetup.Validate("LCY Code", Currency.code);
        GLSetup.Modify();
    end;

    procedure FillCustomerAddressFastTab(var Customer: Record Customer)
    var
        PostCode: Record "Post Code";
    begin
        SSLib.CreatePostCode(PostCode);

        Customer.Validate("Country/Region Code", PostCode."Country/Region Code");
        Customer.Validate("Post Code", PostCode.Code);
        Customer.Validate(Address, 'Rua X');
        Customer.Validate(County, 'Felgueiras');
        Customer.Validate(City, LibUti.GenerateRandomText(5));
        Customer.Modify();
    end;

    procedure FillPostingGroups(var Item: Record Item; var Customer: Record Customer; CreateVAtPostSetup: Boolean): Code[20]
    var
        GenProdPostGrp: Record "Gen. Product Posting Group";
        GenBusinessPostingGroup: Record "Gen. Business Posting Group";
        VATProdPostGrp: Record "VAT Product Posting Group";
        VATBusinessPostingGroup: Record "VAT Business Posting Group";
        GenPostSetup: Record "General Posting Setup";
        VATPostSetup: Record "VAT Posting Setup";
    begin
        VATProdPostGrp.Get(Item."VAT Prod. Posting Group");
        //if(VATPostSetup.get(Customer."VAT Bus. Posting Group", item."VAT Prod. Posting Group")) then ;
        If CreateVAtPostSetup and (VATPostSetup."VAT Bus. Posting Group" = '') then begin
            SSLib.CreateVATBusinessSetupLine(VATPostSetup, VATProdPostGrp, Customer);
            FillSaftFieldsOnVATPostingSetup(VATPostSetup, VATPostSetup."PTSS SAF-T PT VAT Type Desc."::"VAT European Union", VATPostSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
            VATBusinessPostingGroup.Get(VATPostSetup."VAT Bus. Posting Group");
        end;

        if (VATProdPostGrp.code = '') then begin
            SSLib.CreateGeneralPostingSetupLine(GenPostSetup, GenBusinessPostingGroup, GenProdPostGrp, VATPostSetup, VATProdPostGrp, VATBusinessPostingGroup, Customer);
            FillGenPostSetupAccounts(GenPostSetup);

            FillItemPostingGroups(Item, GenProdPostGrp, VATProdPostGrp);
        end;

        exit(Customer."Gen. Bus. Posting Group");
    end;

    local procedure FillSaftFieldsOnVATPostingSetup(var VATPostSetup: Record "VAT Posting Setup"; "PTSS SAF-T PT VAT Type Desc.": Option; "PTSS SAF-T PT VAT Code": Option)
    var
        VATClause: Record "VAT Clause";
        GLAcc: Record "G/L Account";
    begin
        VATClause.Init();
        VATClause.Code := LibUti.GenerateRandomCode(VATClause.FieldNo(Code), Database::"VAT Clause");
        VATClause.Description := LibUti.GenerateRandomCode(VATClause.FieldNo(Description), Database::"VAT Clause");
        VATClause.Insert();

        VATPostSetup.Validate("PTSS SAF-T PT VAT Type Desc.", "PTSS SAF-T PT VAT Type Desc.");
        VATPostSetup.Validate("PTSS SAF-T PT VAT Code", "PTSS SAF-T PT VAT Code");
        SSLib.CreateAuxGLAcc(GLAcc, LibUti.GenerateRandomCode(GLAcc.FieldNo(Name), Database::"G/L Account"));
        VATPostSetup.Validate("PTSS Return VAT Acc. (Sales)", GLAcc."No.");
        VATPostSetup.Validate("PTSS Return VAT Acc. (Purch.)", GLAcc."No.");

        VATPostSetup.Validate("VAT Clause Code", VatClause.Code);
        // VATPostSetup.Modify();
    end;

    procedure UpdateLine(var SalesHeader: Record "Sales Header"; Amount: Integer; UnitPrice: Decimal; QtyToInvoice: Integer)
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.FindFirst();
        //SalesLine.Amount := Amount;
        SalesLine.validate(amount, amount);
        SalesLine.Validate("Unit Price", UnitPrice);
        SalesLine.Validate("Qty. to Invoice", QtyToInvoice);
        SalesLine.Modify();
    end;

    procedure UpdatePostedReturnOrderSeries(NoSeriesCode: Code[20])
    var
        PurchSetup: Record "Purchases & Payables Setup";
    begin
        PurchSetup.Get();
        PurchSetup."Posted Return Shpt. Nos." := NoSeriesCode;
        PurchSetup.Modify();
    end;

    procedure UpdateReturnOrderSeries(NoSeriesCode: Code[20])
    var
        PurchSetup: Record "Purchases & Payables Setup";
    begin
        PurchSetup.Get();
        PurchSetup."Return Order Nos." := NoSeriesCode;
        PurchSetup.Modify();
    end;

    procedure FillVendorAddressFastTab(var Vendor: Record Vendor)
    var
        PostCode: Record "Post Code";
        CountryRegion: Record "Country/Region";
    begin
        SSLib.CreatePostCode(PostCode);
        Vendor."Post Code" := PostCode.Code;
        LibERM.CreateCountryRegion(CountryRegion);
        Vendor."Country/Region Code" := CountryRegion.Code;
        Vendor.Address := 'Rua X';
        Vendor.City := LibUti.GenerateRandomText(5);
    end;

    procedure FillPostingGroupsVendor(var Item: Record Item; var Vendor: Record Vendor; CreateVatSetup: Boolean): Code[20]
    var
        GenProdPostGrp: Record "Gen. Product Posting Group";
        VATProdPostGrp: Record "VAT Product Posting Group";
        GenPostSetup: Record "General Posting Setup";
        VATPostSetup: Record "VAT Posting Setup";
    begin
        if CreateVatSetup then begin
            SSLib.CreateVATPostingSetupLine(VATPostSetup, VATProdPostGrp, Vendor);
            FillSaftFieldsOnVATPostingSetup(VATPostSetup, VATPostSetup."PTSS SAF-T PT VAT Type Desc."::"VAT European Union", VATPostSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
        end;

        SSLib.CreateGeneralPostingSetupLineVendor(genPostSetup, GenProdPostGrp, VATPostSetup, VATProdPostGrp, Vendor);
        FillGenPostSetupAccounts(GenPostSetup);

        FillItemPostingGroups(Item, GenProdPostGrp, VATProdPostGrp);

        exit(Vendor."Gen. Bus. Posting Group");
    end;


    procedure DeleteSalesInvoice(SalesHeader: Record "Sales Header")
    var
        PostedSalesInvoice: Record "Sales Invoice Header";
    begin
        PostedSalesInvoice.SetFilter("Sell-to Customer No.", SalesHeader."Sell-to Customer No.");
        if PostedSalesInvoice.FindFirst() then begin
            PostedSalesInvoice.Delete(true);
        end;
    end;

    procedure FillGenPostSetupAccounts(var GenPostSetup: Record "General Posting Setup")
    var
        LibAssembly: Codeunit "Library - Assembly";
        GLAcc: Record "G/L Account";
        GLAccNo: Code[20];
    begin
        GenPostSetup.Validate("Sales Account", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Sales Credit Memo Account", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Sales Line Disc. Account", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Sales Inv. Disc. Account", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Sales Prepayments Account", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Purch. Account", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Purch. Credit Memo Account", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Purch. Line Disc. Account", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Purch. Inv. Disc. Account", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Purch. Prepayments Account", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("COGS Account", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("COGS Account (Interim)", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Inventory Adjmt. Account", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Invt. Accrual Acc. (Interim)", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Direct Cost Applied Account", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Overhead Applied Account", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Purchase Variance Account", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("PTSS Cr.M Dir. Cost Appl. Acc.", CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Modify();
    end;

    local procedure FillItemPostingGroups(var Item: Record Item; var GenProdPostGrp: Record "Gen. Product Posting Group"; var VATProdPostGrp: Record "VAT Product Posting Group")
    begin
        if Item."No." = '' then
            CreateItemWithInventoryAtDate(Item, LibRandom.RandIntInRange(10, 30), WorkDate(), GenProdPostGrp.Code);
        Item.Get(Item."No.");
        Item."Gen. Prod. Posting Group" := GenProdPostGrp.Code;
        //Item."VAT Prod. Posting Group" := VATProdPostGrp.Code;
        Item.Modify();
    end;

    procedure CreateItemWithInventoryAtDate(var Item: Record Item; QtyToInsert: Decimal; PostingDate: Date; GenProdPostGrp: Code[20])
    var
        ItemJnLine: Record "Item Journal Line";
        Template: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        "General Posting Setup": Record "General Posting Setup";
        InventoryPostingGroup: Record "Inventory Posting Group";
        InventoryPostingSetup: Record "Inventory Posting Setup";
        GLAcc: Record "G/L Account";
    begin
        "General Posting Setup".FindSet();
        "General Posting Setup".FindFirst();

        LibInv.CreateInventoryPostingGroup(InventoryPostingGroup);
        LibInv.CreateInventoryPostingSetup(InventoryPostingSetup, '', InventoryPostingGroup.Code);
        LibERM.CreateGLAccount(GLAcc);
        InventoryPostingSetup.Validate("Inventory Account", GLAcc."No.");
        InventoryPostingSetup.Modify();

        LibInv.CreateItem(Item);
        LibInv.CreateItemJournalTemplate(Template);
        LibInv.CreateItemJournalBatch(Batch, Template.Name);
        LibInv.CreateItemJournalLine(ItemJnLine, Template.Name, Batch.Name, ItemJnLine."Entry Type"::"Positive Adjmt.", Item."No.", QtyToInsert);
        ItemJnLine.Validate("Gen. Prod. Posting Group", "General Posting Setup"."Gen. Prod. Posting Group");
        ItemJnLine.Validate("Gen. Bus. Posting Group", "General Posting Setup"."Gen. Bus. Posting Group");
        ItemJnLine."Posting Date" := PostingDate;
        ItemJnLine.Modify();
        LibInv.PostItemJournalLine(ItemJnLine."Journal Template Name", ItemJnLine."Journal Batch Name");
    end;

    procedure UpdateSalesHeaderPostingNoSeries(var SalesHeader: Record "Sales Header"; NoSeriesCode: Code[20])
    begin
        SalesHeader."Posting No. Series" := NoSeriesCode;
        SalesHeader.Modify();
    end;

    procedure UpdateCreditToFields(var SalesCrMemo: Record "Sales Header"; SalesInv: Record "Sales Header"; VATamount: Integer; VATAmountLCY: Integer; Qty: Integer; UnitCostLCY: Decimal; UnitCost: Decimal; LineAmount: Integer; Amount: Integer; AmountIncludingVAT: Integer)
    var
        SalesLine: Record "Sales Line";
        SalesInvLine: Record "Sales Invoice Line";
        SalesInvoice: Record "Sales Invoice Header";
    begin
        SalesLine.SetRange("Document No.", SalesCrMemo."No.");
        SalesLine.FindFirst();

        SalesInvoice.SetRange("Bill-to Customer No.", SalesInv."Bill-to Customer No.");
        SalesInvoice.FindFirst();

        SalesInvLine.SetRange("Document No.", SalesInvoice."No.");
        SalesInvLine.FindFirst();

        SalesLine."PTSS Credit-to Doc. No." := SalesInvoice."No.";
        SalesLine."PTSS Credit-to Doc. Line No." := SalesInvLine."Line No.";

        SalesLine.Validate("VAT Base Amount", VATamount);
        SalesLine.Validate("Prepmt. VAT Amount Inv. (LCY)", VATAmountLCY);
        SalesLine.Validate("Qty. per Unit of Measure", Qty);
        SalesLine.Validate("Unit Cost (LCY)", UnitCostLCY);
        SalesLine.Validate("Unit Price", UnitCost);
        SalesLine.Validate("Line Amount", LineAmount);
        SalesLine.Validate(Amount, Amount);


        SalesLine."Amount Including VAT" := AmountIncludingVAT;
        SalesLine.Modify(true);
    end;

    procedure CreateGLAccount(var GLAccount: Record "G/L Account"; IncomeBalance: Option; No: Code[20]; AccountType: Enum "G/L Account Type"): Code[20]
    var
        TaxonomyCodes: Record "PTSS Taxonomy Codes";
        CompanyInformation: Record "Company Information";
    begin
        if GLAccount.get(No) then begin
            repeat
                No := Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999));
            until not GLAccount.get(No);
        end;

        GLAccount.Init();
        // Prefix a number to fix errors for local build.
        GLAccount."No." := No;
        GLAccount."Income/Balance" := IncomeBalance;
        GLAccount.Name := GLAccount."No.";  // Enter No. as Name because value is not important.
        GLAccount.Validate("Account Type", AccountType);
        GLAccount.Validate("Gen. Bus. Posting Group", 'NAC');
        GLAccount.Validate("VAT Bus. Posting Group", 'NACIONAL');
        GLAccount.Validate("Gen. Prod. Posting Group", 'MERC');
        GLAccount.Validate("VAT Prod. Posting Group", 'EX_ISE');
        if GLAccount."Account Type" = GLAccount."Account Type"::Posting then begin
            CompanyInformation.get();
            TaxonomyCodes.SetRange("Taxonomy Reference", CompanyInformation."PTSS Taxonomy Reference");
            if TaxonomyCodes.FindSet() then begin
                GLAccount.Validate("PTSS Taxonomy Code", TaxonomyCodes."Taxonomy Code");
            end;
        end;
        if GLAccount."Income/Balance" = GLAccount."Income/Balance"::"Income Statement" then begin
            GLAccount.Validate("PTSS Income Stmt. Bal. Acc.", '111');
        end;
        GLAccount.Insert(true);
        exit(GLAccount."No.");
    end;

    procedure UpdateTransferOrderSeries(NoSeriesCode: Code[20]; DocType: Text)
    var
        InvSetup: Record "Inventory Setup";
    begin
        InvSetup.Get();
        case DocType of
            'Transfer Order':
                InvSetup.Validate("Transfer Order Nos.", NoSeriesCode);
            'Posted Transfer Order':
                InvSetup.Validate("Posted Transfer Shpt. Nos.", NoSeriesCode);
        end;
        InvSetup.Modify();
    end;

    procedure PostTransferOrder(var TransferHeader: Record "Transfer Header")
    var
        WareHouseLib: Codeunit "Library - Warehouse";
    begin
        WareHouseLib.PostTransferOrder(TransferHeader, true, false);
    end;

    procedure GiveLocationInvPostingSetupLine(var Location: Record Location): Code[20]
    var
        InvPostingSetup: Record "Inventory Posting Setup";
        InvPostingGrp: Record "Inventory Posting Group";
        GLAcc: Record "G/L Account";
        LibUtil: Codeunit "Library - Utility";
    begin
        LibInv.CreateInventoryPostingGroup(InvPostingGrp);
        LibInv.CreateInventoryPostingSetup(InvPostingSetup, Location.Code, InvPostingGrp.Code);
        InvPostingSetup."Inventory Account" := CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
        InvPostingSetup.Modify();
        exit(InvPostingGrp.Code);
    end;

    procedure EditCreditInvoiceField(var NoSeries: Record "No. Series")
    begin
        NoSeries.Validate("PTSS Credit Invoice", not NoSeries."PTSS Credit Invoice");
        NoSeries.Modify();
    end;

    procedure GetPostedInvoiceNo(SalesHeader: Record "Sales Header"; CustNo: Code[20]): Code[20]
    var
        SalesInvoice: Record "Sales Invoice Header";
    begin
        Commit();
        SalesInvoice.SetFilter("Sell-to Customer No.", CustNo);
        if SalesInvoice.FindFirst() then
            exit(SalesInvoice."No.");
    end;

    procedure UpdateExactCostReverseMandatory()
    var
        SalesSetup: Record "Sales & Receivables Setup";
    begin
        if SalesSetup.get then begin
            SalesSetup."Exact Cost Reversing Mandatory" := true;
            SalesSetup.Modify();
        end;
    end;

    procedure ClearApplyFromItemEntryField(SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, Enum::"Sales Line Type"::Item);
        if SalesLine.FindFirst() then begin
            ItemLedgerEntry.SetRange("Item No.", SalesLine."No.");
            if ItemLedgerEntry.FindLast() then begin
                SalesLine."Appl.-from Item Entry" := ItemLedgerEntry."Entry No.";
                SalesLine.Modify();
            end;
        end;
    end;

    procedure UpdateSalesDocLineAmount(SalesDoc: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document No.", SalesDoc."No.");
        SalesLine.SetRange(Type, Enum::"Sales Line Type"::Item);
        if SalesLine.FindFirst() then begin
            SalesLine."Line Amount" := 99999;
            SalesLine.Modify();
        end;
    end;

    procedure FillCreditToFields(SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindFirst() then begin
            SalesLine."PTSS Credit-to Doc. No." := '1';
            SalesLine."PTSS Credit-to Doc. Line No." := 1;
            SalesLine.Modify();
        end;
    end;

    procedure ClearCreditToFields(SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindFirst() then begin
            SalesLine."PTSS Credit-to Doc. No." := '';
            SalesLine."PTSS Credit-to Doc. Line No." := 0;
            SalesLine.Modify();
        end;
    end;

    procedure UpdatePostingSeries(var SalesHeader: Record "Sales Header"; PostingSeries: Code[20]; ReturnReceiptSeries: Code[20])
    begin
        SalesHeader."Posting No. Series" := PostingSeries;
        SalesHeader."Return Receipt No. Series" := ReturnReceiptSeries;
        SalesHeader.Modify();
    end;

    procedure CheckGLMovs(var PurchHeader: Record "Purchase Header"; var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line")
    var
        GLEntry: Record "G/L Entry";
        Record_Count: Integer;
        ToPay: Decimal;
        VATDeduct: Decimal;
        VATND: Decimal;
        TotalCost: Decimal;
        Account_D: code[30];
        Account_ND: code[30];
    begin
        /* GLEntry.SetRange("Posting Date", WorkDate());
        GLEntry.SetFilter("Document Type", format(GLEntry."Document Type"::Invoice)); */

        GLEntry.FindSet();
        repeat
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then
                TotalCost := GLEntry.Amount;
            if GLEntry."Gen. Posting Type" = Enum::"General Posting Type"::Purchase then
                ToPay := GLEntry.Amount;
            if not (GLEntry."Gen. Posting Type" = Enum::"General Posting Type"::Purchase) and not ((GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '')) then
                if GLEntry.Amount > 0 then begin
                    VATDeduct := GLEntry.Amount;
                    Account_D := GLEntry."G/L Account No.";
                end else begin
                    VATND := GLEntry.Amount;
                    Account_ND := GLEntry."G/L Account No.";
                end;
        until GLEntry.Next() = 0;

        Verify."Check If MovsGL Values Are correct"(GLEntry.Count, ToPay, VATDeduct, VATND, TotalCost, Account_D, Account_ND);

    end;

    procedure ChangeItemsCompensationFields(var Item: Record Item)
    begin
        Item."PTSS Product ID" := LibUti.GenerateRandomText(4);
        Item."PTSS Size" := 14;
        Item."PTSS Unit Tax Amount" := 15;
        Item.Modify();
    end;

    procedure AttributeFairCompensationToItem(FairCompSetup: Record "PTSS Fair Compensation Setup"; var Item: Record Item)
    begin
        Item.Get(Item."No.");
        Item.Validate("PTSS Product ID", FairCompSetup."PTSS Product ID");
        Item.Modify();
    end;

    procedure FillShippingNoSeries(var SalesHeader: Record "Sales Header"; NoSeries: Record "No. Series")
    begin
        if NoSeries.code = '' then begin
            NoSeries.Get(SalesHeader."No. Series");
        end;
        SalesHeader."Shipping No. Series" := NoSeries.Code;
        SalesHeader.Modify();
    end;

    procedure FillCrMmDirCostApplAcc(var GenPostingSetup: Record "General Posting Setup"; GLAcc: Record "G/L Account")
    begin
        GenPostingSetup."PTSS Cr.M Dir. Cost Appl. Acc." := GLAcc."No.";
        GenPostingSetup.Modify();
    end;

    procedure UpdateCheckChartOfAccounts(Bool: Boolean)
    var
        GLSetup: Record "General Ledger Setup";
    begin
        if GLSetup.Get then begin
            GLSetup.Validate("PTSS Check Chart of Accounts", Bool);
            GLSetup.Modify(true);
        end;
    end;

    procedure UpdateGLAccountNo(var GLAcc: Record "G/L Account"; NewNo: Code[20])
    var
        GLAccCard: TestPage "G/L Account Card";
    begin
        GlAccCard.OpenEdit();
        GlAccCard.GoToRecord(GLAcc);
        GlAccCard."No.".SetValue(NewNo);
        GlAccCard.Close();
    end;

    procedure UpdateAccountType(var GLAcc: Record "G/L Account"; AccountType: Option)
    begin
        GLAcc.Validate("Account Type", AccountType);
        GLAcc.Modify(true);
    end;

    procedure UpdateIncStmtBalAcc(var GLAcc: Record "G/L Account")
    var
        AuxAcc: Record "G/L Account";
    begin
        SSLib.CreateAuxGLAcc(AuxAcc, Format(LibRandom.RandIntInRange(1000, 4999)));
        GLAcc.Validate("PTSS Income Stmt. Bal. Acc.", AuxAcc."No.");
        GLAcc.Modify();
    end;

    procedure RunCheckChartFunction(var GLAcc: Record "G/L Account")
    var
        ChartOfAccsPage: TestPage "Chart of Accounts";
    begin
        ChartOfAccsPage.OpenEdit();
        ChartOfAccsPage.GoToRecord(GLAcc);
        ChartOfAccsPage."PTSS CheckChart".Invoke();
    end;

    procedure ChangeGLAccIncomeBalField(var GLAcc: Record "G/L Account"; IncomeBalance: Option)
    begin
        GLAcc.Validate("Income/Balance", IncomeBalance);
        GLAcc.Modify();
    end;

    procedure AttributeCustGrpReceivablesAcc(CustomerPostingGroup: Code[20])
    var
        CustPostingGrp: Record "Customer Posting Group";
        GLAcc: Record "G/L Account";
    begin
        CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
        CustPostingGrp.Get(CustomerPostingGroup);
        CustPostingGrp."Receivables Account" := GLAcc."No.";
        CustPostingGrp.Modify();
    end;

    procedure OpenTestPage(var GenJournalPage: TestPage "General Journal")
    begin
        GenJournalPage.OpenEdit();
        GenJournalPage.First();
    end;

    procedure OpenCustomerBankAccountPage(var CustomerBankAccPage: TestPage "Customer Bank Account Card"; CustBankAcc: Record "Customer Bank Account")
    begin
        CustomerBankAccPage.OpenEdit();
        CustomerBankAccPage.GoToRecord(CustBankAcc);
    end;

    procedure OpenVendorBankAccountPage(var VendorBankAccPage: TestPage "Vendor Bank Account Card"; VendorBankAcc: Record "Vendor Bank Account")
    begin
        VendorBankAccPage.OpenEdit();
        VendorBankAccPage.GoToRecord(VendorBankAcc);
    end;

    procedure ChangeBankAccNoSeries(NoSeriesCode: Code[20])
    var
        GLSetup: Record "General Ledger Setup";
    begin
        GLSetup.Get;
        GLSetup."Bank Account Nos." := NoSeriesCode;
        GLSetup.Modify();
    end;

    procedure AssociateCashFlowPlanToAccount(var GLAcc: Record "G/L Account"; cashFlowPlanNo: Code[20])
    begin
        GLAcc."PTSS Cash-flow code" := CashFlowPlanNo;
        GLAcc."PTSS Cash-flow code assoc." := true;
        GLAcc.Modify();
    end;

    procedure FillStampDutyField(SalesInv: Record "Sales Header"; Code: Code[10])
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document No.", SalesInv."No.");
        //SalesLine.SetFilter("Document No.", SalesInv."No.")
        SalesLine.FindFirst();
        SalesLine.Validate("VAT Calculation Type", SalesLine."VAT Calculation Type"::"PTSS Stamp Duty");
        SalesLine.Validate("PTSS Stamp Duty Code", Code);
        SaleSLine.Validate("PTSS Territoriality Code", Enum::"PTSS Territoriality Code"::"1 - Art.º 4.º n.º 1 CIS");
        SalesLine.Modify(true);
    end;

    procedure UpdateVATPostingSetupCalcType(VATBusPostingGrp: Code[20]; VATProdPostingGrp: Code[20])
    var
        VATPostingSetup: Record "VAT Posting Setup";
    begin
        VATPostingSetup.Get(VATBusPostingGrp, VATProdPostingGrp);
        VATPostingSetup."VAT Calculation Type" := VATPostingSetup."VAT Calculation Type"::"PTSS Stamp Duty";
        VATPostingSetup.Modify();
    end;

    procedure UpdateTerritorialCode(SalesInv: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetFilter("Document No.", SalesInv."No.");
        SalesLine.FindFirst();
        SalesLine."PTSS Territoriality Code" := SalesLine."PTSS Territoriality Code"::"1 - Art.º 4.º n.º 1 CIS";
        SalesLine.Modify();
    end;

    procedure UpdateBPTerritoryCode(var CountryRegion: Record "Country/Region"; BPTerrCode: Code[3])
    begin
        CountryRegion."PTSS BP Territory Code" := BPTerrCode;
        CountryRegion.Modify();
    end;

    procedure UpdateBPFieldsOnBankAcc(var BankAcc: Record "Bank Account"; BPAccountType: Record "PTSS BP Account Type"; BPStatistic: Record "PTSS BP Statistic")
    begin
        BankAcc."PTSS BP Account Type Code" := BPAccountType.Code;
        BankAcc."PTSS BP Statistic Code" := BPStatistic.Code;
        BankAcc.Modify();
    end;

    procedure UpdateBPStatCategory(var BPStat: Record "PTSS BP Statistic"; Category: Option)
    begin
        BPStat.Category := Category;
        BPStat.Modify();
    end;

    procedure FillBPFields(Code1: Code[1])
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
    begin
        GeneralLedgerSetup.Get();
        GeneralLedgerSetup."PTSS BP Nature Delete Code" := Code1;
        GeneralLedgerSetup."PTSS BP Rec Nature Creat. Code" := GeneralLedgerSetup."PTSS BP Rec Nature Creat. Code"::C;
        GeneralLedgerSetup."PTSS BP Rec. Nature Mod. Code" := Code1;
        GeneralLedgerSetup."PTSS Cur. Dec. Unit Dec. Place" := 1;
        GeneralLedgerSetup."PTSS BP Amount Type Inc. Code" := Code1;
        GeneralLedgerSetup."PTSS BP Amount Type Out. Code" := Code1;
        GeneralLedgerSetup."PTSS BP Amount Type Pos. Code" := Code1;
        GeneralLedgerSetup."PTSS BP Account Type Def. Code" := Code1;
        GeneralLedgerSetup."PTSS BP IF Code" := Code1;
        GeneralLedgerSetup.Modify();
    end;

    procedure UpdateCountryRegionBPTerritory(var CountryRegion: Record "Country/Region"; BPTerritory: Record "PTSS BP Territory")
    begin
        CountryRegion."PTSS BP Territory Code" := BPTerritory.Code;
        CountryRegion.Modify();
    end;

    procedure UpdateBankAccPostingGroup(var BankAcc: Record "Bank Account")
    var
        BankAccPostGrp: Record "Bank Account Posting Group";
        GLAcc: Record "G/L Account";
    begin
        LibERM.CreateBankAccountPostingGroup(BankAccPostGrp);
        CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
        BankAccPostGrp."G/L Account No." := GLAcc."No.";
        BankAccPostGrp.Modify();
        BankAcc."Bank Acc. Posting Group" := BankAccPostGrp.Code;
        BankAcc.Modify();
    end;

    procedure RunGenerateLedgerEntriesFunction()
    var
        BPLedgEntriesPage: TestPage "PTSS BP Ledger Entries";
    begin
        BPLedgEntriesPage.OpenEdit();
        BPLedgEntriesPage."Generate Ledger Entries".Invoke();
    end;

    procedure CreateAndPostBPJournalLine(BankAcc: Record "Bank Account"; BPAccountType: Record "PTSS BP Account Type"; BPStatistic: Record "PTSS BP Statistic"; BPTerritory: Record "PTSS BP Territory")
    var
        LibJournal: Codeunit "Library - Journals";
        GenJournalLine: Record "Gen. Journal Line";
        GenJournal: Record "Gen. Journal Batch";
        GLAcc: Record "G/L Account";
    begin
        LibJournal.CreateGenJournalLineWithBatch(GenJournalLine, GenJournalLine."Document Type"::" ", GenJournalLine."Account Type"::"Bank Account", BankAcc."No.", 20);
        GenJournalLine."PTSS BP Account Type Code" := BPAccountType.Code;
        GenJournalLine."PTSS BP Statistic Code" := BPStatistic.Code;
        GenJournalLine."PTSS BP Bal. Active Ctry. Code" := BPTerritory.Code;
        GenJournalLine."PTSS BP Bal. Count. Ctry. Code" := BPTerritory.Code;
        GenJournalLine."PTSS BP Active Country Code" := BPTerritory.Code;
        GenJournalLine."Due Date" := Today();
        GenJournalLine."Posting Date" := Today();
        GenJournalLine."Document Date" := Today();
        GenJournalLine."PTSS BP Countrpt. Country Code" := BPTerritory.Code;
        GenJournalLine."PTSS BP Bal. Statistic Code" := BPTerritory.Code;

        GenJournalLine."Bal. Account Type" := GenJournalLine."Bal. Account Type"::"G/L Account";

        CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(999), Enum::"G/L Account Type"::Posting);
        GLAcc.Validate("Direct Posting", true);
        GenJournalLine."Bal. Account No." := GLAcc."No.";

        GenJournalLine.Modify();
        LibERM.PostGeneralJnlLine(GenJournalLine);
    end;

    procedure CalcPhysInvForItem()
    var
        PhysInvJournalPage: TestPage "Phys. Inventory Journal";
    begin
        Commit();
        PhysInvJournalPage.OpenEdit();
        PhysInvJournalPage.CalculateInventory.Invoke();
        PhysInvJournalPage.Close();
    end;

    procedure ChangeItemJournalLinePhysInv(QtyCounted: Decimal; GenProdPostGrp: Code[20])
    var
        ItemJournalLines: Record "Item Journal Line";
        GeneralPostingSetup: Record "General Posting Setup";
    begin
        ItemJournalLines.FindSet();
        repeat
            ItemJournalLines."Location Code" := '';
            if not GeneralPostingSetup.Get('', ItemJournalLines."Gen. Prod. Posting Group") then
                LibERM.CreateGeneralPostingSetup(GeneralPostingSetup, '', ItemJournalLines."Gen. Prod. Posting Group");
            //ItemJournalLines."Gen. Prod. Posting Group" := GenProdPostGrp;
            ItemJournalLines.Validate("Qty. (Phys. Inventory)", QtyCounted);
            //ItemJournalLines.Validate(Quantity, QtyCounted - 10);
            ItemJournalLines.Modify();
            Clear(GeneralPostingSetup);
        until ItemJournalLines.Next = 0;
    end;

    procedure PostPhysInvJournal()
    var
        PhysInvPage: TestPage "Phys. Inventory Journal";
    begin
        PhysInvPage.OpenEdit();
        PhysInvPage."P&ost".Invoke();
    end;

    procedure CashVATCustomer(var Customer: Record Customer)
    begin
        Customer."PTSS Cash VAT Customer" := true;
        Customer."PTSS Create Receipt" := true;
        Customer.Modify();
    end;

    procedure UpdateCreateReceiptFieldOnCustomer(var Customer: Record Customer; CreateReceipt: Boolean; CashVATCustomer: boolean)
    begin
        Customer.Validate("PTSS Create Receipt", CreateReceipt);
        Customer.Validate("PTSS Cash VAT Customer", CashVATCustomer);
        Customer.Modify(true);
    end;

    procedure RegisterCustPaymentWithCashReceiptJournal(Customer: Record Customer)
    var
        CashReceiptJournalPage: TestPage "Cash Receipt Journal";
        PostedSalesInvoice: Record "Sales Invoice Header";
        GLAcc: Record "G/L Account";
    begin
        CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);

        PostedSalesInvoice.SetFilter("Bill-to Customer No.", Customer."No.");
        PostedSalesInvoice.FindFirst();

        CashReceiptJournalPage.OpenEdit();
        CashReceiptJournalPage."Document No.".SetValue(10);
        CashReceiptJournalPage."Document Type".SetValue(Enum::"Gen. Journal Document Type"::Payment);
        CashReceiptJournalPage."Account Type".SetValue(Enum::"Gen. Journal Account Type"::Customer);
        CashReceiptJournalPage."Account No.".SetValue(Customer."No.");
        CashReceiptJournalPage."Applies-to Doc. Type".SetValue(Enum::"Gen. Journal Document Type"::Invoice);
        CashReceiptJournalPage."Applies-to Doc. No.".Lookup();

        CashReceiptJournalPage.Description.SetValue(LibUti.GenerateRandomText(4));
        CashReceiptJournalPage."PTSS Create Receipt".SetValue(true);
        CashReceiptJournalPage."Bal. Account No.".SetValue(GLAcc."No.");
        CashReceiptJournalPage.Post.Invoke();
    end;

    procedure UpdateItemCategoryAT(var ItemCategory: Record "Item Category"; PTSSATItemCategory: Option)
    begin
        ItemCategory."PTSS AT Item Category" := PTSSATItemCategory;
        ItemCategory.Modify();
    end;

    procedure UpdateItemCategory(Item: Record Item; ItemCategory: Record "Item Category")
    var
        ItemRef: Record Item;
    begin
        ItemRef.Get(Item."No.");
        ItemRef.Validate("Item Category Code", ItemCategory.Code);
        ItemRef.Modify();
    end;

    procedure UpdateLocationType(var Location: Record Location; PTSSLocationTypeEnum: Enum "PTSS Location Type Enum")
    begin
        Location."PTSS Location Type" := PTSSLocationTypeEnum;
        Location.Modify();
    end;

    procedure UpdateExternalEntityNo(var Location: Record Location; EntityNo: Code[20])
    begin
        Location.Validate("PTSS External Entity No.", EntityNo);
        Location.Modify(True);
    end;

    procedure ChangeSalesReport(DocType: Text; ReportID: Text)
    var
        RepSelectionSalesPage: TestPage "Report Selection - Sales";
    begin
        RepSelectionSalesPage.OpenEdit();
        RepSelectionSalesPage.ReportUsage.SetValue(DocType);
        RepSelectionSalesPage."Report ID".SetValue(ReportID);
        RepSelectionSalesPage.Close();
    end;


    procedure UpdateSAFTWorkingDocType(NoSeries: Record "No. Series"; SAFTWorkingDocType: Enum "PTSS SAF-T Working Doc Type Enum")
    begin
        NoSeries."PTSS SAF-T Working Doc Type" := SAFTWorkingDocType;
        NoSeries.Modify();
    end;

    procedure FillVATFields(VATBusPostingGroup: Code[20]; VATProdPostingGroup: Code[20]; VatCode: Option; VatTypeDesc: Option; "VAT%": Decimal)
    var
        VATPostingSetup: Record "VAT Posting Setup";
    begin
        VATPostingSetup.Get(VATBusPostingGroup, VATProdPostingGroup);
        // VATPostingSetup."PTSS SAF-T PT VAT Code" := 3;
        // VATPostingSetup."PTSS SAF-T PT VAT Type Desc." := 3;
        // VATPostingSetup."PTSS VAT N.D. %" := 0;
        VATPostingSetup.Validate("PTSS SAF-T PT VAT Code", VatCode);
        VATPostingSetup.Validate("PTSS SAF-T PT VAT Type Desc.", VatTypeDesc);
        VATPostingSetup."PTSS VAT N.D. %" := "VAT%";
        VATPostingSetup.Modify();
    end;

    procedure FillLCYCodeFieldInGenLedgSetup()
    var
        Currency: Record Currency;
        GenLedgSetup: Record "General Ledger Setup";
    begin
        LibERM.CreateCurrency(Currency);
        GenLedgSetup.Get();
        GenLedgSetup."LCY Code" := Currency.Code;
        GenLedgSetup.Modify();
    end;

    procedure PrintSalesQuote(SalesHeader: Record "Sales Header")
    var
        SalesQuotePage: TestPage "Sales Quote";
        SalesQuoteRep: Report "PTSS Sales Quote (PT)";

        SalesLine: Record "Sales Line";
    begin
        // SalesQuotePage.OpenEdit();
        // SalesQuotePage.GoToRecord(SalesHeader);
        // SalesQuotePage."PTSS Print".Invoke();
        // SalesQuotePage.Close();

        Report.Run(report::"PTSS Sales Quote (PT)", false, false, SalesHeader);
    end;

    procedure PrintSalesOrder(SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("document No.", SalesHeader."No.");
        SalesLine.FindLast();
        case SalesHeader."Document Type" of
            SalesHeader."Document Type"::Order:
                begin
                    Report.Run(report::"PTSS Sales order (PT)", false, false, SalesHeader);
                end;
            SalesHeader."Document Type"::"Blanket Order":
                begin
                    Report.Run(report::"PTSS Blanket Sales Order (PT)", false, false, SalesHeader);
                end;
        end;
    end;

    procedure DeleteSalesDoc(var SalesHeader: Record "Sales Header")
    var
        SAlesLine: Record "Sales Line";
        SalesHeader1: Record "Sales Header";
        PostSalesDelete: Codeunit "PostSales-Delete";
    begin
        //SalesHeader.Get(SalesHeader."Document Type", SalesHeader."No.");
        SalesLine.get(SalesHeader."Document Type", SalesHeader."No.", 10000);
        SalesHeader.Delete(True);
        //PostSalesDelete.Run();
        //SalesHeader := SalesHeader1;
    end;

    procedure PostSalesDocument(SalesHeader: Record "Sales Header"; var SalesHeader2: Record "Sales Header")
    begin
        SalesHeader2.Get(SalesHeader."Document Type", SalesHeader."No.");
        SSLib.PostSalesDocument(SalesHeader2, True, True);
    end;

    procedure PrintProforma(var SalesHeader: Record "Sales Header")
    var
        SalesOrderPage: TestPage "Sales Order";
        DocPrint: Codeunit "Document-Print";
    begin
        // SalesOrderPage.OpenEdit();
        // SalesOrderPage.GoToRecord(SalesHeader);
        // SalesOrderPage."PTSS ProformaInvoice".Invoke();
        // SalesOrderPage.Close();

        // DocPrint.PrintProformaSalesInvoice(SalesHeader);

        Report.Run(report::"PTSS ProForma Invoice (PT)", false, false, SalesHeader);
    end;

    procedure UpdateGenLedgSetupForSEPA()
    var
        GenLedgSetup: Record "General Ledger Setup";
    begin
        GenLedgSetup.Get;
        GenLedgSetup."LCY Code" := 'EUR';
        GenLedgSetup."SEPA Non-Euro Export" := True;
        GenLedgSetup.Modify();
    end;

    procedure UpdateBankAccExportFields(var CompBankAcc: Record "Bank Account")
    var
        BankExport: Record "Bank Export/Import Setup";
    begin
        BankExport.SetFilter(Code, 'SEPACT');
        BankExport.FindFirst();
        CompBankAcc."Payment Export Format" := BankExport.Code;
        CompBankAcc.Modify();
    end;

    procedure UpdateBankAccWithRequiredFieldsForSEPA(var CompBankAcc: Record "Bank Account"; NoSeriesCode: Code[20])
    var
        ValidIBAN: Label 'PT50000757437360445536654';
    begin
        CompBankAcc.Validate("Credit Transfer Msg. Nos.", NoSeriesCode);
        CompBankAcc.Validate("SWIFT Code", CreateSWIFT());
        CompBankAcc."Currency Code" := 'EUR';
        CompBankAcc.Validate(IBAN, ValidIBAN);
        CompBankAcc.Modify();
    end;

    local procedure CreateSWIFT(): Code[20]
    var
        SwiftCode: Record "SWIFT Code";
    begin
        SwiftCode.Init;
        SwiftCode.Code := LibUti.GenerateRandomText(5);
        SwiftCode.Name := LibUti.GenerateRandomText(5);
        SwiftCode.Insert();
        exit(SwiftCode.Code);
    end;

    procedure UpdateGenJournalBatchBalancingFields(var GenJournalBatch: Record "Gen. Journal Batch"; CompBankAccNo: Code[20])
    begin
        GenJournalBatch.Validate("Bal. Account Type", GenJournalBatch."Bal. Account Type"::"Bank Account");
        GenJournalBatch.Validate("Bal. Account No.", CompBankAccNo);
        GenJournalBatch.Validate("Allow Payment Export", True);
        GenJournalBatch.Modify();
    end;

    procedure UpdateVendorForSEPA(Vendor: Record Vendor; VendorBankAccCode: Code[20]; CurrencyCode: Code[10]; CountryRegionCode: Code[20])
    begin
        Vendor.Validate("Currency Code", CurrencyCode);
        Vendor.Validate("Country/Region Code", CountryRegionCode);
        Vendor.Validate("Creditor No.", '123');
        Vendor.Validate("Preferred Bank Account Code", VendorBankAccCode);
        Vendor.Modify();
    end;

    procedure CreatePaymentLineForVendor(var PaymentJournal: TestPage "Payment Journal"; BatchName: Code[10]; VendorNo: Code[20]; BankAccNo: Code[20])
    begin
        PaymentJournal.OpenEdit();
        PaymentJournal.CurrentJnlBatchName.SetValue(BatchName);
        PaymentJournal.First();
        PaymentJournal."Document No.".SetValue(123);
        PaymentJournal."Account Type".SetValue('Vendor');
        PaymentJournal."Account No.".SetValue(VendorNo);
        PaymentJournal."Currency Code".SetValue('EUR');
        PaymentJournal."Recipient Bank Account".SetValue(BankAccNo);
        PaymentJournal.Amount.SetValue(20.5);
    end;



    //####################################################################################################################


    internal procedure ModifyFieldAndValidate(Variant: Variant; FieldNo: Integer; arg: Text)
    var
        RecRef: RecordRef;
        Field: FieldRef;
    begin
        RecRef.GetTable(Variant);
        Field := RecRef.Field(FieldNo);
        Field.Validate(arg);
        RecRef.SetTable(Variant);
        RecRef.Modify();
    end;

    procedure OpenPageAndPutRecord(var SalesOrder: TestPage "Sales Order"; SalesHeader: Record "Sales Header")
    begin
        SalesOrder.OpenEdit();
        SalesOrder.GoToRecord(SalesHeader);
    end;

    procedure OpenPageAndPutRecord(var CurrencyCard: TestPage "Currency Card"; Currency: REcord Currency)
    begin
        CurrencyCard.OpenEdit();
        CurrencyCard.GoToRecord(Currency);
    end;

    procedure OpenPageAndPutRecord(var CustCard: TestPage "Customer Card"; Customer: Record Customer)
    begin

        CustCard.OpenEdit();
        CustCard.GoToRecord(Customer);
    end;

    procedure OpenPageAndPutRecord(var DirectDebtCollections: TestPage "Direct Debit Collections")
    var
        directDebitColl: Record "Direct Debit Collection";
    begin
        directDebitColl.FindSet();
        DirectDebtCollections.OpenEdit();
        DirectDebtCollections.GoToRecord(directDebitColl);
    end;

    procedure OpenPageAndPutRecord(var SalesInvoiceTestPage: TestPage "Sales Invoice"; SalesInvoice: Record "Sales Header")
    begin
        SalesInvoiceTestPage.OpenEdit();
        SalesInvoiceTestPage.GoToRecord(SalesInvoice);
    end;

    procedure OpenPageAndPutRecord(var PostedSalesInvoiceTestPage: TestPage "Posted Sales Invoice"; PostedSalesInvoice: Record "Sales Invoice Header")
    begin
        PostedSalesInvoiceTestPage.OpenEdit();
        PostedSalesInvoiceTestPage.GoToRecord(PostedSalesInvoice);
    end;

    procedure OpenPageAndPutRecord(var PaymentJournal: TestPage "Payment Journal"; PurchasePayment: Record "Gen. Journal Line")
    begin
        PaymentJournal.OpenView();
        PaymentJournal.GoToRecord(PurchasePayment);
    end;

    procedure OpenPageAndPutRecord(var VendorCard: TestPage "Vendor Card"; Vendor: Record Vendor)
    begin
        VendorCard.OpenEdit();
        VendorCard.GoToRecord(Vendor);
    end;

    procedure OpenPageAndPutRecord(var "General Journal": TestPage "General Journal"; var "General Journal Line": Record "Gen. Journal Line")
    begin
        "General Journal".OpenEdit();
        "General Journal".New();
        "General Journal"."Posting Date".SetValue("General Journal Line"."Posting Date");
        "General Journal"."Document No.".SetValue("General Journal Line"."Document No.");
        "General Journal"."Account Type".SetValue("General Journal Line"."Account Type");
        "General Journal"."Account No.".SetValue("General Journal Line"."Account No.");
        "General Journal".Description.SetValue("General Journal Line".Description);
        "General Journal"."Bal. Account No.".SetValue("General Journal Line"."Bal. Account No.");
        "General Journal"."Bal. Account Type".SetValue("General Journal Line"."Bal. Account Type");
        "General Journal"."PTSS Posting Group".SetValue("General Journal Line"."Posting Group");
        "General Journal".Amount.SetValue("General Journal Line".Amount);
    end;

    procedure OpenPageAndPutRecord(var "Cash Receipt Journal": TestPage "Cash Receipt Journal"; var "General Journal Line": Record "Gen. Journal Line")
    begin
        "Cash Receipt Journal".OpenEdit();
        "Cash Receipt Journal".New();
        "Cash Receipt Journal"."Posting Date".SetValue("General Journal Line"."Posting Date");
        "Cash Receipt Journal"."Document No.".SetValue("General Journal Line"."Document No.");
        "Cash Receipt Journal"."Account Type".SetValue("General Journal Line"."Account Type");
        "Cash Receipt Journal"."Account No.".SetValue("General Journal Line"."Account No.");
        "Cash Receipt Journal".Description.SetValue("General Journal Line".Description);
        "Cash Receipt Journal"."Bal. Account No.".SetValue("General Journal Line"."Bal. Account No.");
        "Cash Receipt Journal"."Bal. Account Type".SetValue("General Journal Line"."Bal. Account Type");
        "Cash Receipt Journal"."PTSS Posting Group".SetValue("General Journal Line"."Posting Group");
        "Cash Receipt Journal".Amount.SetValue("General Journal Line".Amount);
        //"Cash Receipt Journal".GoToRecord("General Journal Line");
    end;

    internal procedure DoesPageExists(Caption: Text): Boolean
    begin
        if Caption <> '' then
            exit(true)
        else
            exit(false);
    end;

    procedure InitializePTSystemLanguage()
    var
        UnitMeasure: Record "Unit of Measure";
        GLACC: REcord "G/L Account";
    begin

        System.GlobalLanguage(2070);

        FillCompanyBasicInfo();

        LibInv.CreateUnitOfMeasureCode(UnitMeasure);

        //WebServiceATSetup();
    end;

    procedure InitializePTSystemLanguage(gIsInitialized: Boolean)
    var
        UnitMeasure: Record "Unit of Measure";
        GLACC: REcord "G/L Account";
        ChartOfAcc: Record "G/L Account";
        aux: Integer;
    begin
        ClearLastError();
        gLibraryVariableStorage.Clear();
        gLibrarySetupStorage.Restore();
        if gIsInitialized then
            exit;

        // if ChartOfAcc.FindSet() then begin
        //     aux := ChartOfAcc.Count();
        //     repeat
        //         ChartOfAcc.CalcFields(Balance);
        //         ChartOfAcc.Validate(Balance, 0);
        //         ChartOfAcc.Modify();
        //     // Clear(ChartOfAcc);
        //     until ChartOfAcc.next() <= 0
        // end;

        gIsInitialized := true;
        Commit();

        //gLibrarySetupStorage.Save(DATABASE::"Vendor Posting Group");
        // gLibrarySetupStorage.Save(DATABASE::"VAT Posting Setup");
        //gLibrarySetupStorage.Save(DATABASE::"G/L Account");

        System.GlobalLanguage(2070);

        FillCompanyBasicInfo();

        LibInv.CreateUnitOfMeasureCode(UnitMeasure);

        //WebServiceATSetup();
    end;

    procedure InitializeCustomerForSAFT(var Customer: Record Customer; NIF: Text[20])
    var
        CustBankAcc: Record "Customer Bank Account";
        Country: Record "Country/Region";
        PostCode: REcord "Post Code";
    begin
        SSLib.CreatePostCode(PostCode);
        if not Country.Get('PT') then
            SSLib.CreatePTCountryRegion(Country);

        LibSales.CreateCustomer(Customer);
        Customer.Validate(Address, LibUti.GenerateRandomCodeWithLength(Customer.FieldNo(Address), Database::Customer, 10));
        LibERM.CreateCountryRegion(Country);
        Customer.Validate("Country/Region Code", Country.Code);
        Customer.Validate("VAT Registration No.", NIF);
        Customer.Validate(City, PostCode.City);
        Customer.Validate("Post Code", PostCode.Code);
        SSLib.CreateCustomerBankAccount(CustBankAcc, Customer."No.", LibUti.GenerateRandomCode20(CustBankAcc.FieldNo(Code), Database::"Customer Bank Account"));
        Customer.Validate("Preferred Bank Account Code", CustBankAcc.Code);
        Customer.Modify();
    end;

    internal procedure InitGlAccountCard(var GLAccountTestPage: TestPage "G/L Account Card"; var GlAccount: Record "G/L Account")
    begin
        GLAccountTestPage.OpenEdit();
        GLAccountTestPage.GoToRecord(GlAccount);
        GlAccount.Modify(true);
        //GLAccountTestPage."No.".setValue(NoValue);

    end;

    procedure InitializeCompanyInfoSAFT(var Customer: Record Customer; var Vendor: Record Vendor; NIF: Code[20])
    begin
        InitializeCustomerForSAFT(Customer, NIF);
        InitializeVendorForSAFT(Vendor);
        InitializeCompanyInfoforSAFT(Customer, Vendor);
    end;

    procedure InitializeVendorForSAFT(var Vendor: REcord Vendor)
    var
        VendBankAcc: Record "Vendor Bank Account";
        PostCode: REcord "Post Code";
        country: Record "Country/Region";
    begin
        SSLib.CreatePostCode(PostCode);
        if not Country.Get('PT') then
            SSLib.CreatePTCountryRegion(Country);

        LibPur.CreateVendor(Vendor);
        Vendor.Validate(Address, 'Rua da Boavista');
        Vendor.Validate("Post Code", PostCode.Code);
        Vendor.Validate(City, PostCode.City);
        Vendor.Validate("VAT Registration No.", SSLib.GenerateRandomPTNIF());
        SSLib.CreateVendorBankAccount(VendBankAcc, Vendor."No.", LibUti.GenerateRandomCode20(VendBankAcc.FieldNo(Code), Database::"Vendor Bank Account"));
        Vendor.Validate("Preferred Bank Account Code", VendBankAcc.Code);
        VEndor.Modify();
    end;

    procedure InitializeCompanyInfoforSAFT(Customer: Record Customer; Vendor: Record Vendor)
    var
        CompanyInfo: Record "Company Information";
        PostCode: REcord "Post Code";
        country: Record "Country/Region";
    begin
        CompanyInfo.Get();
        if CompanyInfo.Name = '' then
            CompanyInfo.Validate(Name, LibUti.GenerateRandomText(6));
        if CompanyInfo.Address = '' then
            CompanyInfo.Validate(Address, LibUti.GenerateRandomText(10));
        if CompanyInfo."Post Code" = '' then begin
            SSLib.CreatePostCode(PostCode);
            CompanyInfo.Validate("Post Code", PostCode.Code);
            CompanyInfo.Validate(City, PostCode.City);
        end;
        if CompanyInfo."Country/Region Code" = '' then begin
            LibErm.CreateCountryRegion(country);
            CompanyInfo.Validate("Country/Region Code", country.Code);
        end;

        CompanyInfo.Validate("PTSS SAFT-PT Company Cust. ID", Customer."No.");
        // CompanyInfo.Validate("PTSS Soft. Vendor VAT Reg. No.", Vendor."No.");
        // CompanyInfo.Validate("PTSS Software Certificate No.", LibUti.GenerateRandomText(4));
        CompanyInfo.Validate("PTSS Taxonomy Reference", CompanyInfo."PTSS Taxonomy Reference"::"S - SNC Base");
        CompanyInfo.Validate("PTSS Business Name", LibUti.GenerateRandomText(10));
        CompanyInfo.Validate("PTSS Registration Authority", LibUti.GenerateRandomText(7));

        CompanyInfo.Modify();
    end;

    internal procedure SetupNoSeriesForPurchCreditMemo()
    var
        PurchPayablesSetup: Record "Purchases & Payables Setup";
        NoSeries: Record "No. Series";
    begin
        PurchPayablesSetup.get();
        PurchPayablesSetup.Validate("Credit Memo Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        PurchPayablesSetup.Validate("Posted Credit Memo Nos.", SSLib.CreateNoSeries(true, false, false, NoSeries."PTSS SAF-T Invoice Type"::"NC"));
        PurchPayablesSetup.Modify();
    end;

    internal procedure SetupNoSeriesForPurchases()
    var
        PurchRec: Record "Purchases & Payables Setup";
        NoSeries: Record "No. Series";
    begin
        PurchRec.Get();
        PurchRec.Validate("Invoice Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        PurchRec.Validate("Posted Invoice Nos.", SSLib.CreateNoSeries(true, false, false, NoSeries."PTSS SAF-T Invoice Type"::"FT"));
        PurchRec.Validate("Order Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        PurchRec.Validate("Posted Receipt Nos.", CreateNoSeries(false, false, false, true, NoSeries."PTSS Receipt Type"::"PTSS Other Receipts", false, false, false, false, true, false, true));
        PurchRec.validate("Return Order Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        PurchRec.validate("Posted Return Shpt. Nos.", SSLib.CreateNoSeries(false, true, false, NoSeries."PTSS GTAT Document Type"::GA));
        PurchRec.validate("Posted Credit Memo Nos.", SSLib.CreateNoSeries(true, false, false, NoSeries."PTSS SAF-T Invoice Type"::"NC"));
        PurchRec.validate("Credit Memo Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        PurchRec.Modify();
    end;

    internal procedure SetupNoSeriesForInvoice()
    var
        SalesRec: Record "Sales & Receivables Setup";
        NoSeries: Record "No. Series";
    begin
        SalesRec.Get();
        SalesRec.Validate("Invoice Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        SalesRec.Validate("Posted Invoice Nos.", SSLib.CreateNoSeries(true, false, false, NoSeries."PTSS SAF-T Invoice Type"::"FT"));
        SalesRec.Modify();
    end;

    internal procedure SetupSameNoSeriesForInvoice()
    var
        SalesRec: Record "Sales & Receivables Setup";
        NoSeries: Record "No. Series";
    begin
        SalesRec.Get();
        SalesRec.Validate("Invoice Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        SalesRec.Validate("Posted Invoice Nos.", SSLib.CreateNoSeries(true, false, false, NoSeries."PTSS SAF-T Invoice Type"::"FT"));
        SalesRec.Modify();
    end;

    internal procedure SetupNoSeriesForCreditMemo()
    var
        SalesRec: Record "Sales & Receivables Setup";
        NoSeries: Record "No. Series";
    begin
        SalesRec.get();
        SalesRec.Validate("Credit Memo Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        SalesRec.Validate("Posted Credit Memo Nos.", SSLib.CreateNoSeries(true, false, false, NoSeries."PTSS SAF-T Invoice Type"::"NC"));
        SalesRec.Modify();
    end;

    internal procedure SetupNoSeriesForDebitMemo()
    var
        SalesRec: Record "Sales & Receivables Setup";
        NoSeries: Record "No. Series";
    begin
        SalesRec.get();
        SalesRec.Validate("PTSS Debit Memo Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        SalesRec.Validate("PTSS Posted Debit Memo Nos.", SSLib.CreateNoSeries(true, false, false, NoSeries."PTSS SAF-T Invoice Type"::"ND"));
        SalesRec.Modify();
    end;

    procedure SetupNoSeriesForVendor()
    var
        PurchPay: Record "Purchases & Payables Setup";
        NoSeries: Record "No. Series";
    begin
        PurchPay.get();
        PurchPay.Validate("Vendor Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        PurchPay.Modify();
    end;

    internal procedure SetupNoSeriesForQuote()
    var
        SalesRec: Record "Sales & Receivables Setup";
        NoSeries: Record "No. Series";
    begin
        SalesRec.Get();
        SalesRec.Validate("Quote Nos.", SSLib.CreateNoSeries(true, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        SalesRec.Modify();

    end;

    internal procedure SetupNoSeriesForWD()
    var
        SalesRec: Record "Sales & Receivables Setup";
        ServiceMgtSetup: Record "Service Mgt. Setup";
        NoSeries: Record "No. Series";
    begin
        SalesRec.Get();
        SalesRec.Validate("PTSS WD Sales Quote Nos.", SSLib.CreateNoSeries(false, false, true, NoSeries."PTSS SAF-T Working Doc Type"::"OR"));
        SalesRec.Validate("PTSS WD Sales Order Nos.", SSLib.CreateNoSeries(false, false, true, NoSeries."PTSS SAF-T Working Doc Type"::"NE"));
        SalesRec.Validate("PTSS WD Proforma Invoice Nos.", SSLib.CreateNoSeries(false, false, true, NoSeries."PTSS SAF-T Working Doc Type"::"PF"));
        SalesRec.Validate("PTSS WD Blank. Sales Order Nos", SSLib.CreateNoSeries(false, false, true, NoSeries."PTSS SAF-T Working Doc Type"::"OU"));
        SalesRec.Modify();

        ServiceMgtSetup.Get();
        ServiceMgtSetup.Validate("PTSS WD Service Order Nos.", SSLib.CreateNoSeries(false, false, true, NoSeries."PTSS SAF-T Working Doc Type"::"NE"));
        ServiceMgtSetup.Validate("PTSS WD Service Quote Nos.", SSLib.CreateNoSeries(false, false, true, NoSeries."PTSS SAF-T Working Doc Type"::"OR"));
        ServiceMgtSetup.Modify();
    end;

    procedure ChangeSalesSetupForDirectShipping()
    var
        PurchRec: Record "Sales & Receivables Setup";
    begin
        PurchRec.Get();
        PurchRec.Validate("Shipment on Invoice", true);
        PurchRec.Validate("Return Receipt on Credit Memo", true);
        PurchRec.Modify();
    end;

    internal procedure FillPostingGroupsForIntraCom(var Item: Record Item; var Vendor: Record Vendor; VATCalculationType: Enum "Tax Calculation Type"; PTSSSAFTPTVATTypeDesc: Option; var GLRegCompra: Record "G/L Account"; var GLRegVenda: Record "G/L Account"; REGCOMPRA: Boolean; REGVENDA: Boolean): Code[20]
    var
        GenProdPostGrp: Record "Gen. Product Posting Group";
        VATProdPostGrp: Record "VAT Product Posting Group";
        GenPostSetup: Record "General Posting Setup";
        VATPostSetup: Record "VAT Posting Setup";
    begin
        SSLib.CreateVATPostingSetupLine(VATPostSetup, VATProdPostGrp, Vendor);
        FillSaftFieldsOnVATPostingSetup(VATPostSetup, GLRegCompra, GLRegVenda, REGCOMPRA, REGVENDA);
        VATPostSetup.Validate("VAT Calculation Type", VATPostSetup."VAT Calculation Type"::"Reverse Charge VAT");
        VATPostSetup.Modify();

        SSLib.CreateGeneralPostingSetupLineVendor(genPostSetup, GenProdPostGrp, VATPostSetup, VATProdPostGrp, Vendor);
        FillGenPostSetupAccounts(GenPostSetup);

        FillItemPostingGroups(Item, GenProdPostGrp, VATProdPostGrp);

        exit(Vendor."Gen. Bus. Posting Group");
    end;

    local procedure FillSaftFieldsOnVATPostingSetup(var VATPostSetup: Record "VAT Posting Setup"; var GLRegCompra: Record "G/L Account"; var GLRegVenda: Record "G/L Account"; RegCompra: Boolean; REgVenda: Boolean)
    var
        VATClause: Record "VAT Clause";
        GLAcc: Record "G/L Account";

    begin
        if RegCompra and RegVenda then begin
            LibERM.CreateGLAccount(GLRegCompra);
            LibERM.CreateGLAccount(GLRegVenda);

            VATPostSetup.VAlIdate("Sales VAT Account", GLRegCompra."No.");
            VATPostSetup.Validate("Purchase VAT Account", GLRegVenda."No.");
        end;

        VATPostSetup."PTSS SAF-T PT VAT Type Desc." := VATPostSetup."PTSS SAF-T PT VAT Type Desc."::"VAT European Union";
        VATPostSetup."PTSS SAF-T PT VAT Code" := VATPostSetup."PTSS SAF-T PT VAT Code"::"No tax rate";
        SSLib.CreateAuxGLAcc(GLAcc, 'saftvat');
        VATPostSetup."PTSS Return VAT Acc. (Sales)" := GLAcc."No.";
        VATPostSetup."PTSS Return VAT Acc. (Purch.)" := GLAcc."No.";
        VATClause.Init();
        VATClause.Code := LibUti.GenerateRandomText(3);
        VATClause.Description := LibUti.GenerateRandomText(3);
        VATClause.Insert();
        VATPostSetup."VAT Clause Code" := VatClause.Code;
        VATPostSetup.Modify();
    end;

    local procedure WebServiceATSetup()
    var
        WS_AT: Record "PTSS Tax Authority WS Setup";
        CompanyInfo: Record "Company Information";
    begin
        WS_AT.Init();
        WS_AT.Validate("XMLNS SoapEnv", 'http://schemas.xmlsoap.org/soap/envelope/');
        WS_AT.Validate("XMLNS Doc", 'https://servicos.portaldasfinancas.gov.pt/sgdtws/documentosTransporte/');
        WS_AT.Validate("XMLNS Wss", 'http://schemas.xmlsoap.org/ws/2002/12/secext');
        WS_AT.Validate("URL Endpoint", 'https://servicos.portaldasfinancas.gov.pt:701/sgdtws/documentosTransporte');
        WS_AT.Validate("SOAP Action", 'http://at.gov.pt/');
        WS_AT.Validate("Enable AT Communication", true);
        WS_AT.Insert();

        CompanyInfo.Get();
        CompanyInfo.Validate("PTSS Tax Authority WS User ID", '510761135/1');
        CompanyInfo.Validate("PTSS Tax Authority WS Password", 'softstoreat');
        CompanyInfo.Modify();
    end;

    internal procedure FindGLentryCount(GLentry: Record "G/L Entry") c: Integer
    begin
        GLentry.SetRange("Document Type", Enum::"Gen. Journal Document Type"::"Credit Memo");
        GLentry.FindSet();
        repeat
            c += 1;
        /* if GLentry."G/L Account No." = GLRegCompra."No." then
            Assert.AreEqual(GLentry."G/L Account No.", GLRegCompra."No.", ErrorAcc);
        if GLentry."G/L Account No." = GLRegVenda."No." then
            Assert.AreEqual(GLentry."G/L Account No.", GLRegVenda."No.", ErrorAcc); */
        until GLentry.Next() = 0;
    end;

    internal procedure UpdatePurchaseOrderPostingGroups(var PurchaseLine: Record "Purchase Line"; "VAT Bus. Posting Group Code": Code[20]; "VAT Prod. Posting Group Code": Code[20]; GenBusPostingGroup: Code[20]; GenProdPostingGroup: Code[20])
    begin
        PurchaseLine."VAT Bus. Posting Group" := "VAT Bus. Posting Group Code";
        PurchaseLine."VAT Prod. Posting Group" := "VAT Prod. Posting Group Code";
        PurchaseLine."Gen. Bus. Posting Group" := GenBusPostingGroup;
        PurchaseLine."Gen. Prod. Posting Group" := GenProdPostingGroup;
        PurchaseLine.Modify();
    end;

    internal procedure PostPurchaseDocument(PurchaseHeader: Record "Purchase Header"; ToShipReceive: Boolean; ToInvoice: Boolean)
    var
        NoSeriesManagement: Codeunit NoSeriesManagement;
        NoSeriesCode: Code[20];
        Assert: Codeunit Assert;
    begin
        // Post the purchase document.
        // Depending on the document type and posting type return the number of the:
        // - purchase receipt,
        // - posted purchase invoice,
        // - purchase return shipment, or
        // - posted credit memo

        with PurchaseHeader do begin
            Validate(Receive, ToShipReceive);
            Validate(Ship, ToShipReceive);
            Validate(Invoice, ToInvoice);

            case "Document Type" of
                "Document Type"::Invoice:
                    NoSeriesCode := "Posting No. Series"; // posted purchase invoice
                "Document Type"::Order:
                    if ToShipReceive and not ToInvoice then
                        NoSeriesCode := "Receiving No. Series" // posted purchase receipt
                    else
                        NoSeriesCode := "Posting No. Series"; // posted purchase invoice
                "Document Type"::"Credit Memo":
                    NoSeriesCode := "Posting No. Series"; // posted purchase credit memo
                "Document Type"::"Return Order":
                    if ToShipReceive and not ToInvoice then
                        NoSeriesCode := "Return Shipment No. Series" // posted purchase return shipment
                    else
                        NoSeriesCode := "Posting No. Series"; // posted purchase credit memo
                else
                    Assert.Fail(StrSubstNo('Document type not supported: %1', "Document Type"))
            end
        end;

        CODEUNIT.Run(CODEUNIT::"Purch.-Post", PurchaseHeader);
    end;

    procedure InitializeSaftTest()
    var
        Customer: Record Customer;
        Vendor: Record Vendor;
        GenLedgSetup: Record "General Ledger Setup";
        Currency: Record Currency;
    begin
        InitializeCompanyInfoSAFT(Customer, Vendor, format(LibRandom.RandIntInRange(100000000, 999999999)));
        InitializePageConfigRegIVA();
        InitializePageMecPayment();
        InitializeTaxonomyCodes();
        InitializeNoSeries();

        SSLib.CreateCurrency(Currency);

        GenLedgSetup.Get();
        GenLedgSetup."LCY Code" := Currency.code;
        GenLedgSetup.Modify();

    end;

    procedure InitializePageConfigRegIVA()
    var
        VatPostSetup: Record "VAT Posting Setup";
        VatClause: Record "VAT Clause";
        VATBusinessPostingGroup: Record "VAT Business Posting Group";
        VATProdPostGrp: REcord "VAT Product Posting Group";
        VATBusinessPosting: TExt;
    begin
        VatPostSetup.SetRange("VAT Bus. Posting Group", 'DOMESTIC');
        VatPostSetup.DeleteAll();

        // if not VatPostSetup.Get('DOMESTIC') then begin
        VATBusinessPosting := LibUti.GenerateRandomText(7);
        SSLib.CreateVATBusinessPostingGroup(VATBusinessPostingGroup, VATBusinessPosting);
        LibERM.CreateVATProductPostingGroup(VATProdPostGrp);
        LibERM.CreateVATPostingSetup(VATPostSetup, VATBusinessPostingGroup.Code, VATProdPostGrp.Code);
        VatPostSetup.Validate("VAT Identifier", 'VAT10');
        VatPostSetup.Validate("VAT %", 10);
        VatPostSetup.Modify();
        // end;
        // Commit();
        VatPostSetup.SetRange("VAT Bus. Posting Group", VATBusinessPosting);
        VatPostSetup.SetFilter("VAT Identifier", 'VAT10');
        if VatPostSetup.FindSet() then
            VatPostSetup.FindFirst();
        VatPostSetup.Validate("PTSS SAF-T PT VAT Type Desc.", VatPostSetup."PTSS SAF-T PT VAT Type Desc."::"VAT Azores");
        VatPostSetup.VAlidate("PTSS SAF-T PT VAT Code", VatPostSetup."PTSS SAF-T PT VAT Code"::"Reduced tax rate");
        SSLib.CreateVATClause(VatClause, LibUti.GenerateRandomText(4));
        VatPostSetup.VAlidate("VAT Clause Code", VatClause.Code);
        VatPostSetup.Modify();
    end;

    procedure InitializePageMecPayment()
    var
        PaymentMethod: REcord "Payment Method";
    begin
        if PaymentMethod.FindSet() then
            PaymentMethod.SetFilter(Code, 'ACCOUNT');
        if PaymentMethod.FindSet() then
            PaymentMethod.FindFirst();
        PaymentMethod.Validate("PTSS SAF-T Pmt. Mechanism", PaymentMethod."PTSS SAF-T Pmt. Mechanism"::"Debit Card");
    end;

    procedure InitializeTaxonomyCodes()
    var
        TaxonomyCode: Record "PTSS Taxonomy Codes";
    begin
        TaxonomyCode.SetRange("Taxonomy Reference", TaxonomyCode."Taxonomy Reference"::"S - SNC Base");
        if TaxonomyCode.FindSet() then begin
            TaxonomyCode.Validate("Taxonomy Code", LibRandom.RandInt(100));
            TaxonomyCode.Validate(Description, 'TEST 1');
            //TaxonomyCode.Modify(true);
        end;
        // TaxonomyCode.Init();

        // TaxonomyCode.Insert();
    end;

    procedure InitializeNoSeries()
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        SeriesCode: Text;
    begin
        LibUti.CreateNoSeries(NoSeries, true, false, false);
        SeriesCode := LibUti.GenerateRandomCode(1, 308);
        LibUti.CreateNoSeriesLine(NoSeriesLine, NoSeries.Code, SeriesCode + '0001', SeriesCode + '9999');
        NoSeriesLine.validate("PTSS SAF-T No. Series Del.", StrLen(SeriesCode));

    end;

    procedure SetfilerForRequestPageVatEntry(var VatEntry: Record "VAT Entry")
    var
        Report: Report 31022927;
    begin
        Commit();
        // Check if its possible to filter Report with given Vat entry filtered
        // [WHEN] Can filter By Date
        VatEntry.SetRange("Posting Date", WorkDate());
        // [WHEN] Can filter By Document type
        VatEntry.SetRange("Document Type", VatEntry."Document Type"::Invoice);
        // [WHEN] Can filter By No Series
        VatEntry.SetRange("No. Series", 'test');
        Clear(Report);
        Report.SetTableView(VatEntry);
        Report.Run();
    end;

    procedure OpenPageAndPutRecord(var CompanyInfoPage: TestPage "Company Information")
    var
        CompanyInfo: Record "Company Information";
    begin
        CompanyInfo.Get();
        CompanyInfoPage.OpenEdit();
        CompanyInfoPage.GoToRecord(CompanyInfo);
    end;

    internal procedure InvokeActionVerificationVAT(var VATRegTestPage: TestPage "VAT Registration Log"; var CompanyInfoTestPage: TestPage "Company Information") Status: Text
    var
        VATRegLog: Record "VAT Registration Log";
    begin

        VATRegTestPage.Trap();
        CompanyInfoTestPage."VAT Registration No.".Lookup();
        VATRegTestPage.OpenEdit();
        VATRegTestPage."Verify VAT Registration No.".Invoke();
        Status := VATRegTestPage.Status.Value;
        VATRegTestPage.Close();
    end;

    internal procedure ExportSaft()
    var
        SaftCard: TestPage "PTSS Export SAF-T";
    begin
        SaftCard.OpenEdit();
        SaftCard.StartDate.SetValue(Calcdate('<-1D>', WorkDate()));
        SaftCard.EndDate.SetValue(Calcdate('<+1D>', WorkDate()));
        SaftCard.AccBasisDataType.SetValue('F - Faturação');
        SaftCard."File Name".SetValue('TesteCase.xml');
        SaftCard."Export SAF-T File".Invoke();
    end;

    internal procedure CreateGLAccountsForVatTesting(var DeductVAT: Record "G/L Account"; var AppliedVAT: Record "G/L Account"; var ToGov: Record "G/L Account"; var ToCompany: Record "G/L Account"; var ReverseCharge: Record "G/L Account")
    begin
        CreateGLAccount(DeductVAT, DeductVAT."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
        CreateGLAccount(AppliedVAT, AppliedVAT."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
        CreateGLAccount(ToGov, ToGov."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
        CreateGLAccount(ToCompany, ToCompany."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
        CreateGLAccount(ReverseCharge, ReverseCharge."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
    end;

    internal procedure ChangeItemUnitPrice(var Item: Record Item; Price: Integer)
    begin
        Item."Unit Price" := Price;
        Item.Modify();
    end;

    procedure UpdateGenJournalLine(var GenJournalLine: Record "Gen. Journal Line"; Customer: Record Customer; Item: Record Item)
    var
        VATPostSetup: Record "VAT Posting Setup";
        VATProdPostGrp: REcord "VAT Product Posting Group";
    begin
        // GenJournalLine."Gen. Bus. Posting Group" := Customer."Gen. Bus. Posting Group";
        // GenJournalLine."Gen. Prod. Posting Group" := Item."Gen. Prod. Posting Group";
        //create VAT Post Setup
        VATProdPostGrp.Get(Item."VAT Prod. Posting Group");
        GenJournalLine."Gen. Posting Type" := GenJournalLine."Gen. Posting Type"::SAle;
        if not VATPostSetup.get(Customer."VAT Bus. Posting Group", Item."VAT Prod. Posting Group") then begin
            SSLib.CreateVATBusinessSetupLine(VATPostSetup, VATProdPostGrp, Customer);
            GenJournalLine."VAT Prod. Posting Group" := Item."VAT Prod. Posting Group";
            GenJournalLine."VAT Bus. Posting Group" := Customer."VAT Bus. Posting Group";
        end;
        GenJournalLine.Modify();
    end;

    procedure UpdateGenJournalLine(var GenJournalLine: Record "Gen. Journal Line"; Vendor: Record Vendor; Item: Record Item)
    var
        VATPostSetup: Record "VAT Posting Setup";
        VATProdPostGrp: REcord "VAT Product Posting Group";
    begin
        // GenJournalLine."Gen. Bus. Posting Group" := Customer."Gen. Bus. Posting Group";
        // GenJournalLine."Gen. Prod. Posting Group" := Item."Gen. Prod. Posting Group";
        //create VAT Post Setup
        VATProdPostGrp.Get(Item."VAT Prod. Posting Group");
        GenJournalLine."Gen. Posting Type" := GenJournalLine."Gen. Posting Type"::SAle;
        if not VATPostSetup.get(Vendor."VAT Bus. Posting Group", Item."VAT Prod. Posting Group") then begin
            SSLib.CreateVATPostingSetupLine(VATPostSetup, VATProdPostGrp, Vendor);
            GenJournalLine."VAT Prod. Posting Group" := Item."VAT Prod. Posting Group";
            GenJournalLine."VAT Bus. Posting Group" := Vendor."VAT Bus. Posting Group";
        end;
        GenJournalLine.Modify();
    end;

    procedure UpdateGenJournalLineForReverseChargeVAT(var GenJournalLine: Record "Gen. Journal Line"; Vendor: Record Vendor; Item: Record Item)
    var
        VATPostSetup: Record "VAT Posting Setup";
        VATProdPostGrp: REcord "VAT Product Posting Group";
    begin
        // GenJournalLine."Gen. Bus. Posting Group" := Customer."Gen. Bus. Posting Group";
        // GenJournalLine."Gen. Prod. Posting Group" := Item."Gen. Prod. Posting Group";
        //create VAT Post Setup
        VATProdPostGrp.Get(Item."VAT Prod. Posting Group");
        GenJournalLine."Gen. Posting Type" := GenJournalLine."Gen. Posting Type"::SAle;
        if not VATPostSetup.get(Vendor."VAT Bus. Posting Group", Item."VAT Prod. Posting Group") then begin
            SSLib.CreateVATPostingSetupLine(VATPostSetup, VATProdPostGrp, Vendor);
            GenJournalLine."VAT Prod. Posting Group" := Item."VAT Prod. Posting Group";
            GenJournalLine."VAT Bus. Posting Group" := Vendor."VAT Bus. Posting Group";
        end;
        // config reverse charge vat
        VATPostSetup."VAT %" := 13;
        VATPostSetup.Modify(true);

        GenJournalLine.Modify(true);
    end;

    #region DavidP

    procedure SetPurchDocForRecoverySeries(var PurchaseHeader: Record "Purchase Header"; PurchaseDocumentType: Enum "Purchase Document Type"; NumberOfOrders: Integer; i: Integer)
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        PurchasesPayablesSetup: Record "Purchases & Payables Setup";
        SAFTTSequentialNo: text;
        PurchaseReturnOrder: TestPage "Purchase Return Order";
        DocCode: Code[20];
    begin
        PurchasesPayablesSetup.Get();
        case PurchaseDocumentType of
            PurchaseDocumentType::"Return Order":
                begin
                    if i = NumberOfOrders then begin
                        NoSeries.get(PurchasesPayablesSetup."PTSS Rec. Ret. Rcp. Series No.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);

                        SAFTTSequentialNo := CopyStr(NoSeriesLine."Starting No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1);
                    end else begin
                        NoSeries.get(PurchaseHeader."No. Series");
                        NoSeriesLine.Get(NoSeries.Code, 10000);

                        SAFTTSequentialNo := CopyStr(PurchaseHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1);

                        NoSeriesLine.Reset();
                        NoSeries.Reset();
                        NoSeries.get(PurchasesPayablesSetup."PTSS Rec. Ret. Rcp. Series No.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);
                    end;
                    PurchaseReturnOrder.OpenEdit();
                    PurchaseReturnOrder.GoToRecord(PurchaseHeader);
                    PurchaseReturnOrder."PTSS Recovery Document Type".SetValue(NoSeries."PTSS GTAT Document Type");
                    PurchaseReturnOrder."PTSS Recovery Series".SetValue(NoSeriesLine."PTSS SAF-T No. Series");
                    PurchaseReturnOrder."PTSS Recovery Document No.".SetValue(SAFTTSequentialNo);
                    PurchaseReturnOrder."PTSS Recovery Posting Date".SetValue(NoSeriesLine."Starting Date");
                    DocCode := PurchaseReturnOrder."No.".Value;
                    PurchaseReturnOrder.Close();

                    PurchaseHeader.Reset();
                    PurchaseHeader.get(PurchaseDocumentType, DocCode);
                end;
        end;
    end;

    procedure PostPurchRecovery(var PurchaseHeader: Record "Purchase Header"; PurchaseDocumentType: Enum "Purchase Document Type")
    var
        PurchaseReturnOrder: TestPage "Purchase Return Order";
        PagePurchaseReturnOrder: Page "Purchase Return Order";
    begin
        case PurchaseDocumentType of
            PurchaseDocumentType::"Return Order":
                begin
                    PurchaseHeader.validate(ship, true);
                    PurchaseHeader.Validate(invoice, true);
                    PurchaseHeader.Modify(true);

                    PurchaseReturnOrder.OpenEdit();
                    PurchaseReturnOrder.GoToRecord(PurchaseHeader);
                    PurchaseReturnOrder.Post.Invoke();
                end;
        end;
    end;

    procedure PostSalesRecovery(SalesHeader: Record "Sales Header"; SalesDocumentType: Enum "Sales Document Type")
    var
        TestPageSalesInvoice: TestPage "Sales Invoice";
        TestPageSalesCreditMemo: TestPage "Sales Credit Memo";
    begin
        case SalesDocumentType of
            SalesDocumentType::Invoice:
                begin
                    TestPageSalesInvoice.OpenEdit();
                    TestPageSalesInvoice.GoToRecord(SalesHeader);
                    TestPageSalesInvoice.Post.Invoke();
                end;
        end;
    end;

    procedure SetupNoSeriesForRecovery()
    var
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
        PurchasesPayablesSetup: Record "Purchases & Payables Setup";
        NoSeries: Record "No. Series";
    begin
        SalesReceivablesSetup.Get();
        SalesReceivablesSetup.Validate("PTSS Rec. Inv. Series No.", CreateNoSeries(true, false, false, false, NoSeries."PTSS SAF-T Invoice Type"::FT, false, false, false, true, true, true, true));
        SalesReceivablesSetup.Validate("PTSS Rec. C.V. Rec. Series No.", CreateNoSeries(false, false, false, true, NoSeries."PTSS Receipt Type"::"PTSS Cash VAT Receipt", false, false, false, true, true, true, true));
        SalesReceivablesSetup.Validate("PTSS Rec. Cr.Memo Series No.", CreateNoSeries(true, false, false, false, NoSeries."PTSS SAF-T Invoice Type"::NC, false, false, false, true, true, true, true));
        SalesReceivablesSetup.Validate("PTSS Rec. Receipt Series No.", CreateNoSeries(false, false, false, true, NoSeries."PTSS Receipt Type"::"PTSS Other Receipts", false, false, false, true, true, true, true));
        SalesReceivablesSetup.Modify(true);

        PurchasesPayablesSetup.get();
        PurchasesPayablesSetup.validate("PTSS Rec. Ret. Rcp. Series No.", CreateNoSeries(false, true, false, false, NoSeries."PTSS GTAT Document Type"::GA, false, false, false, true, true, true, true));
        PurchasesPayablesSetup.modify();
    end;

    procedure SetSalesDocForRecoverySeries(var SalesHeader: Record "Sales Header"; SalesDocumentType: Enum "Sales Document Type"; NumberOfOrders: Integer; i: Integer; SalesInvoiceHeader: record "Sales Invoice Header")
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
        SAFTTSequentialNo: text;
        TestPageSalesInvoice: TestPage "Sales Invoice";
        TestPageSalesCreditMemo: TestPage "Sales Credit Memo";
        DocCode: Code[20];
    begin
        SalesReceivablesSetup.Get();
        case SalesDocumentType of
            SalesDocumentType::Invoice:
                begin
                    if i = NumberOfOrders then begin
                        NoSeries.get(SalesReceivablesSetup."PTSS Rec. Inv. Series No.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);

                        SAFTTSequentialNo := CopyStr(NoSeriesLine."Starting No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1);
                    end else begin
                        NoSeries.get(SalesHeader."No. Series");
                        NoSeriesLine.Get(NoSeries.Code, 10000);

                        SAFTTSequentialNo := CopyStr(SalesHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1);

                        NoSeriesLine.Reset();
                        NoSeries.Reset();
                        NoSeries.get(SalesReceivablesSetup."PTSS Rec. Inv. Series No.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);
                    end;
                    TestPageSalesInvoice.OpenEdit();
                    TestPageSalesInvoice.GoToRecord(SalesHeader);
                    TestPageSalesInvoice."PTSS Rec Document Type".SetValue(NoSeries."PTSS SAF-T Invoice Type");
                    TestPageSalesInvoice."PTSS Rec Series".SetValue(NoSeriesLine."PTSS SAF-T No. Series");
                    TestPageSalesInvoice."PTSS Rec Document No.".SetValue(SAFTTSequentialNo);
                    TestPageSalesInvoice."PTSS Rec Document Date".SetValue(NoSeriesLine."Starting Date");
                    DocCode := TestPageSalesInvoice."No.".Value;
                    TestPageSalesInvoice.Close();

                    SalesHeader.Reset();
                    SalesHeader.get(SalesDocumentType, DocCode);
                end;
            SalesDocumentType::"Credit Memo":
                begin
                    if i = NumberOfOrders then begin
                        NoSeries.get(SalesReceivablesSetup."PTSS Rec. Cr.Memo Series No.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);

                        SAFTTSequentialNo := CopyStr(NoSeriesLine."Starting No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1);
                    end else begin
                        NoSeries.get(SalesHeader."No. Series");
                        NoSeriesLine.Get(NoSeries.Code, 10000);

                        SAFTTSequentialNo := CopyStr(SalesHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1);

                        NoSeriesLine.Reset();
                        NoSeries.Reset();
                        NoSeries.get(SalesReceivablesSetup."PTSS Rec. Cr.Memo Series No.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);
                    end;

                    TestPageSalesCreditMemo.OpenEdit();
                    TestPageSalesCreditMemo.GoToRecord(SalesHeader);
                    TestPageSalesCreditMemo."PTSS Rec Document Type".SetValue(NoSeries."PTSS SAF-T Invoice Type");
                    TestPageSalesCreditMemo."PTSS Rec Series".SetValue(NoSeriesLine."PTSS SAF-T No. Series");
                    TestPageSalesCreditMemo."PTSS Rec Document No.".SetValue(SAFTTSequentialNo);
                    TestPageSalesCreditMemo."PTSS Rec Document Date".SetValue(NoSeriesLine."Starting Date");
                    SalesHeader.Reset();

                    SalesHeader.get(TestPageSalesCreditMemo."No.");
                    TestPageSalesCreditMemo.Close();
                end;
        end;
    end;

    procedure SetPurchaseForRecoverySeries(var PurchaseHeader: Record "Purchase Header"; PurchaseDocumentType: Enum "Purchase Document Type"; NumberOfOrders: Integer; i: Integer; ReturnShipmentHeader: record "Return Shipment Header")
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        PurchasesPayablesSetup: Record "Purchases & Payables Setup";
        SAFTTSequentialNo: text;
        PagePurchaseReturnOrder: Page "Purchase Return Order";
    begin
        PurchasesPayablesSetup.Get();
        case PurchaseDocumentType of
            PurchaseDocumentType::"Return Order":
                begin
                    if i = NumberOfOrders then begin
                        NoSeries.get(PurchasesPayablesSetup."PTSS Rec. Ret. Rcp. Series No.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);

                        SAFTTSequentialNo := CopyStr(NoSeriesLine."Starting No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1);
                    end else begin
                        NoSeries.get(PurchaseHeader."No. Series");
                        NoSeriesLine.Get(NoSeries.Code, 10000);

                        SAFTTSequentialNo := CopyStr(PurchaseHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1);

                        NoSeriesLine.Reset();
                        NoSeries.Reset();
                        NoSeries.get(PurchasesPayablesSetup."PTSS Rec. Ret. Rcp. Series No.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);
                    end;

                    PagePurchaseReturnOrder.SetRecord(PurchaseHeader);
                    PagePurchaseReturnOrder.SetIntegrationDocumentFields(NoSeries.Code, NoSeries."PTSS GTAT Document Type", SAFTTSequentialNo, ReturnShipmentHeader."PTSS Hash", '1234', NoSeriesLine."PTSS AT Validation Code", NoSeriesLine."Starting Date");
                    PagePurchaseReturnOrder.GetRecord(PurchaseHeader);
                end;
        end;
    end;

    procedure SetPurchaseDocForIntegratedSeries(var PurchaseHeader: Record "Purchase Header"; PurchaseDocumentType: Enum "Purchase Document Type"; NumberOfOrders: Integer; i: Integer; ReturnShipmentHeader: record "Return Shipment Header")
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        PurchasesPayablesSetup: Record "Purchases & Payables Setup";
        SAFTTSequentialNo: text;
        PagePurchaseReturnOrder: Page "Purchase Return Order";
    begin
        PurchasesPayablesSetup.Get();
        case PurchaseDocumentType of
            PurchaseDocumentType::"Return Order":
                begin
                    if i = NumberOfOrders then begin
                        NoSeries.get(PurchasesPayablesSetup."PTSS Int. Ret. Rcp. Series No.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);

                        SAFTTSequentialNo := CopyStr(NoSeriesLine."Starting No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1);
                    end else begin
                        NoSeries.get(PurchaseHeader."No. Series");
                        NoSeriesLine.Get(NoSeries.Code, 10000);

                        SAFTTSequentialNo := CopyStr(PurchaseHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1);

                        NoSeriesLine.Reset();
                        NoSeries.Reset();
                        NoSeries.get(PurchasesPayablesSetup."PTSS Int. Ret. Rcp. Series No.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);
                    end;

                    PagePurchaseReturnOrder.SetRecord(PurchaseHeader);
                    PagePurchaseReturnOrder.SetIntegrationDocumentFields(NoSeries.Code, NoSeries."PTSS GTAT Document Type", SAFTTSequentialNo, ReturnShipmentHeader."PTSS Hash", '1234', NoSeriesLine."PTSS AT Validation Code", NoSeriesLine."Starting Date");
                    PagePurchaseReturnOrder.GetRecord(PurchaseHeader);
                end;
        end;
    end;

    procedure ValidateHashNoPurch(NumberOfOrders: Integer; IsIntegretion: Boolean; IsRecovery: Boolean)
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        PurchasesPayablesSetup: Record "Purchases & Payables Setup";
        ReturnShipmentHeader: Record "Return Shipment Header";
        PreviousHashNo, NewHashtNo, LastHashUsed : Text;
        NoSeriesMgt: Codeunit "PTSS No. Series Management";
        SSHashDocType, SSHashNoSeries, SSHashDocNo : Code[100];
        SSHashAmountIncludingVAT: Decimal;
    begin
        PurchasesPayablesSetup.Get();
        NoSeries.Get(PurchasesPayablesSetup."Posted Return Shpt. Nos.");
        NoSeriesLine.Get(NoSeries.Code, 10000);

        if IsIntegretion then begin
            NoSeries.Reset();
            NoSeriesLine.Reset();
            NoSeries.Get(PurchasesPayablesSetup."PTSS Int. Ret. Rcp. Series No.");
            NoSeriesLine.Get(NoSeries.Code, 10000);
        end;

        if IsRecovery then begin
            NoSeries.Reset();
            NoSeriesLine.Reset();
            NoSeries.Get(PurchasesPayablesSetup."PTSS Rec. Ret. Rcp. Series No.");
            NoSeriesLine.Get(NoSeries.Code, 10000);
        end;

        ReturnShipmentHeader.RESET;
        ReturnShipmentHeader.setrange("No. Series", NoSeriesLine."Series Code");
        IF ReturnShipmentHeader.FindSet() THEN BEGIN
            REPEAT
                NoSeriesMgt.GetAndValidateNoSeriesLine(ReturnShipmentHeader."No. Series", ReturnShipmentHeader."Posting Date", true, NoSeriesLine, 2);
                SSHashDocType := SSCreateSignature.GetGTATDocumentTypeBySeriesNo(NoSeriesLine."Series Code");
                SSHashNoSeries := NoSeriesLine."PTSS SAF-T No. Series";
                SSHashDocNo := CopyStr(ReturnShipmentHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1, StrLen(ReturnShipmentHeader."No."));
                SSHashAmountIncludingVAT := 0;


                PreviousHashNo := SSCreateSignature.GetHash(SSHashDocType, ReturnShipmentHeader."Posting Date", SSHashDocNo, SSHashNoSeries, ReturnShipmentHeader."Currency Code", ReturnShipmentHeader."Currency Factor", SSHashAmountIncludingVAT, PreviousHashNo, ReturnShipmentHeader."PTSS Creation Date", ReturnShipmentHeader."PTSS Creation Time");

                Verify.HashNoIsSequential(PreviousHashNo, ReturnShipmentHeader."PTSS Hash");
            UNTIL ReturnShipmentHeader.Next() = 0;
        END;
    end;

    procedure SetSalesDocForIntegratedSeries(var SalesHeader: Record "Sales Header"; SalesDocumentType: Enum "Sales Document Type"; NumberOfOrders: Integer; i: Integer; SalesInvoiceHeader: record "Sales Invoice Header")
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
        SAFTTSequentialNo: text;
        PageSalesInvoice: Page "Sales Invoice";
        PageSalesCreditMemo: Page "Sales Credit Memo";
    begin
        SalesReceivablesSetup.Get();
        case SalesDocumentType of
            SalesDocumentType::Invoice:
                begin
                    if i = NumberOfOrders then begin
                        NoSeries.get(SalesReceivablesSetup."PTSS Int. Inv. Series No.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);

                        SAFTTSequentialNo := CopyStr(NoSeriesLine."Starting No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1);
                    end else begin
                        NoSeries.get(SalesHeader."No. Series");
                        NoSeriesLine.Get(NoSeries.Code, 10000);

                        SAFTTSequentialNo := CopyStr(SalesHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1);

                        NoSeriesLine.Reset();
                        NoSeries.Reset();
                        NoSeries.get(SalesReceivablesSetup."PTSS Int. Inv. Series No.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);
                    end;

                    PageSalesInvoice.SetRecord(SalesHeader);
                    PageSalesInvoice.SetIntegrationDocumentFields(NoSeries.Code, NoSeries."PTSS SAF-T Invoice Type", SAFTTSequentialNo, SalesInvoiceHeader."PTSS Hash", '1234', NoSeriesLine."PTSS AT Validation Code", NoSeriesLine."Starting Date");
                    PageSalesInvoice.GetRecord(SalesHeader);
                end;
            SalesDocumentType::"Credit Memo":
                begin
                    if i = NumberOfOrders then begin
                        NoSeries.get(SalesReceivablesSetup."PTSS Int. Cr.Memo Series No.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);

                        SAFTTSequentialNo := CopyStr(NoSeriesLine."Starting No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1);
                    end else begin
                        NoSeries.get(SalesHeader."No. Series");
                        NoSeriesLine.Get(NoSeries.Code, 10000);

                        SAFTTSequentialNo := CopyStr(SalesHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1);

                        NoSeriesLine.Reset();
                        NoSeries.Reset();
                        NoSeries.get(SalesReceivablesSetup."PTSS Int. Cr.Memo Series No.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);
                    end;

                    PageSalesCreditMemo.SetRecord(SalesHeader);
                    PageSalesCreditMemo.SetIntegrationDocumentFields(NoSeries.Code, NoSeries."PTSS SAF-T Invoice Type", SAFTTSequentialNo, SalesInvoiceHeader."PTSS Hash", '1234', NoSeriesLine."PTSS AT Validation Code", NoSeriesLine."Starting Date");
                    PageSalesCreditMemo.GetRecord(SalesHeader);
                end;
        end;
    end;

    procedure SetupNoSeriesForIntegration()
    var
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
        PurchasesPayablesSetup: Record "Purchases & Payables Setup";
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        SalesReceivablesSetup.Get();
        SalesReceivablesSetup.Validate("PTSS Int. Inv. Series No.", CreateNoSeries(true, false, false, false, NoSeries."PTSS SAF-T Invoice Type"::FT, false, false, true, false, true, true, true));
        SalesReceivablesSetup.Validate("PTSS Int. C.V. Rec. Series No.", CreateNoSeries(false, false, false, true, NoSeries."PTSS Receipt Type"::"PTSS Cash VAT Receipt", false, false, true, false, true, true, true));
        SalesReceivablesSetup.Validate("PTSS Int. Cr.Memo Series No.", CreateNoSeries(true, false, false, false, NoSeries."PTSS SAF-T Invoice Type"::NC, false, false, true, false, true, true, true));
        SalesReceivablesSetup.Validate("PTSS Int. Receipt Series No.", CreateNoSeries(false, false, false, true, NoSeries."PTSS Receipt Type"::"PTSS Other Receipts", false, false, true, false, true, true, true));
        SalesReceivablesSetup.Modify(true);

        PurchasesPayablesSetup.get();
        PurchasesPayablesSetup.validate("PTSS Int. Ret. Rcp. Series No.", CreateNoSeries(false, true, false, false, NoSeries."PTSS GTAT Document Type"::GA, false, false, true, false, true, true, true));
        PurchasesPayablesSetup.modify();
    end;

    procedure ValidateHashNoService(NumberOfOrders: Integer; ServiceDocumentType: Enum "Service Document Type")
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        ServiceMgtSetup: Record "Service Mgt. Setup";
        ServiceInvoiceHeader: Record "Service Invoice Header";
        ServiceCrMemoHeader: Record "Service Cr.Memo Header";
        PreviousHashNo, NewHashtNo, LastHashUsed : Text;
        NoSeriesMgt: Codeunit "PTSS No. Series Management";
        SSHashDocType, SSHashNoSeries, SSHashDocNo : Code[100];
        SSHashAmountIncludingVAT: Decimal;
    begin
        ServiceMgtSetup.Get();

        if (ServiceDocumentType = ServiceDocumentType::Invoice) then begin
            NoSeries.Get(ServiceMgtSetup."Posted Service Invoice Nos.");
            NoSeriesLine.Get(NoSeries.Code, 10000);

            ServiceInvoiceHeader.RESET;
            ServiceInvoiceHeader.SetRange("No. Series", NoSeries.Code);
            IF ServiceInvoiceHeader.FindSet() THEN BEGIN
                REPEAT
                    NoSeriesMgt.GetAndValidateNoSeriesLine(ServiceInvoiceHeader."No. Series", ServiceInvoiceHeader."Posting Date", true, NoSeriesLine, 1);
                    SSHashDocType := SSCreateSignature.GetInvoiceDocumentTypeBySeriesNo(NoSeriesLine."Series Code");
                    SSHashNoSeries := NoSeriesLine."PTSS SAF-T No. Series";
                    SSHashDocNo := CopyStr(ServiceInvoiceHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1, StrLen(ServiceInvoiceHeader."No."));
                    ServiceInvoiceHeader.CalcFields("Amount Including VAT");
                    SSHashAmountIncludingVAT := ABS(ServiceInvoiceHeader."Amount Including VAT");

                    PreviousHashNo := SSCreateSignature.GetHash(SSHashDocType, ServiceInvoiceHeader."Posting Date", SSHashDocNo, SSHashNoSeries, ServiceInvoiceHeader."Currency Code", ServiceInvoiceHeader."Currency Factor", SSHashAmountIncludingVAT, PreviousHashNo, ServiceInvoiceHeader."PTSS Creation Date", ServiceInvoiceHeader."PTSS Creation Time");

                    Verify.HashNoIsSequential(PreviousHashNo, ServiceInvoiceHeader."PTSS Hash");
                UNTIL ServiceInvoiceHeader.Next() = 0;
            END;
        end;
        if ServiceDocumentType = ServiceDocumentType::"Credit Memo" then begin
            NoSeries.Get(ServiceMgtSetup."Posted Serv. Credit Memo Nos.");
            NoSeriesLine.Get(NoSeries.Code, 10000);

            ServiceCrMemoHeader.RESET;
            ServiceCrMemoHeader.SetRange(ServiceCrMemoHeader."No. Series", NoSeries.code);
            IF ServiceCrMemoHeader.FindSet() THEN BEGIN
                REPEAT
                    NoSeriesMgt.GetAndValidateNoSeriesLine(ServiceCrMemoHeader."No. Series", ServiceCrMemoHeader."Posting Date", true, NoSeriesLine, 1);
                    SSHashDocType := SSCreateSignature.GetInvoiceDocumentTypeBySeriesNo(NoSeriesLine."Series Code");
                    SSHashNoSeries := NoSeriesLine."PTSS SAF-T No. Series";
                    SSHashDocNo := CopyStr(ServiceCrMemoHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1, StrLen(ServiceCrMemoHeader."No."));
                    ServiceCrMemoHeader.CalcFields("Amount Including VAT");
                    SSHashAmountIncludingVAT := ABS(ServiceCrMemoHeader."Amount Including VAT");

                    PreviousHashNo := SSCreateSignature.GetHash(SSHashDocType, ServiceCrMemoHeader."Posting Date", SSHashDocNo, SSHashNoSeries, ServiceCrMemoHeader."Currency Code", ServiceCrMemoHeader."Currency Factor", SSHashAmountIncludingVAT, PreviousHashNo, ServiceCrMemoHeader."PTSS Creation Date", ServiceCrMemoHeader."PTSS Creation Time");

                    Verify.HashNoIsSequential(PreviousHashNo, ServiceCrMemoHeader."PTSS Hash");
                UNTIL ServiceCrMemoHeader.Next() = 0;
            END;
        end;
    end;

    procedure UpdateGenJournalLineForReverseChargeVATV2(var GenJournalLine: Record "Gen. Journal Line"; No: Code[20])
    var
        customer: Record Customer;
        vendor: Record vendor;
        VATPostSetup: Record "VAT Posting Setup";
        VATProdPostGrp: Record "VAT Product Posting Group";
        VATBusPostGrp: Record "VAT Business Posting Group";
    begin
        case GenJournalLine."Account Type" of
            GenJournalLine."Account Type"::Customer:
                begin
                    customer.get(No);
                end;
            GenJournalLine."Account Type"::vendor:
                begin
                    vendor.get(No);
                end;
        end;
        // VATBusPostGrp.Get(vendor."VAT Bus. Posting Group");
        // VATProdPostGrp.get(GenJournalLine."VAT Prod. Posting Group");
        // VATPostSetup.get(VATBusPostGrp.Code, VATProdPostGrp.code);
        // VATPostSetup.Validate("VAT Calculation Type", VATPostSetup."VAT Calculation Type"::"Reverse Charge VAT");
        // VATPostSetup.Modify();

        GenJournalLine.Validate("VAT Calculation Type", VATPostSetup."VAT Calculation Type"::"Reverse Charge VAT");
        GenJournalLine.Modify();
    end;

    procedure ValidateSequenceNoSeriesReceipt(ReceiptTypes: Enum "PTSS Receipt Types")
    var
        NoSeries, NoSeries2 : Record "No. Series";
        NoSeriesLine, NoSeriesLine2 : Record "No. Series Line";
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
        PreviousDocumentNo, NextDocumentNo : Integer;
        ReceiptHeader: Record "PTSS Receipt Header";
        ServiceInvoiceHeader: Record "Service Invoice Header";
        ServiceCrMemoHeader: Record "Service Cr.Memo Header";
        ReturnReceiptHeader: Record "Return Receipt Header";
    begin
        SalesReceivablesSetup.Get();

        case ReceiptTypes of
            ReceiptTypes::"PTSS Other Receipts":
                begin
                    NoSeries.Get(SalesReceivablesSetup."PTSS Receipt Nos.");
                    NoSeriesLine.Get(NoSeries.Code, 10000);
                end;
            ReceiptTypes::"PTSS Cash VAT Receipt":
                begin
                    NoSeries.Get(SalesReceivablesSetup."PTSS Cash VAT Receipt Nos.");
                    NoSeriesLine.Get(NoSeries.Code, 10000);
                end;
        end;

        ReceiptHeader.RESET;
        ReceiptHeader.setrange("No. Series", NoSeriesLine."Series Code");
        IF ReceiptHeader.FindSet() THEN BEGIN
            REPEAT
                PreviousDocumentNo := NextDocumentNo;
                Evaluate(NextDocumentNo, CopyStr(ReceiptHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1, StrLen(NoSeriesLine."PTSS SAFT-T Sequential No.")));
                Verify.NoSeriesIsSequential(PreviousDocumentNo, NextDocumentNo);
            UNTIL ReceiptHeader.Next() = 0;
        END;
    end;

    procedure AddDiscountAndWithholdingTaxToThePurchLine(var PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line"; DocumentLine: Integer; Discount: Decimal; HasWithholding: Boolean; Withholding1: Decimal; Withholding2: Decimal)
    var
        WithholdingTaxCodes: Record "PTSS Withholding Tax Codes";
    begin
        PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", DocumentLine);
        PurchaseLine.validate("Line Discount %", Discount);

        if HasWithholding then begin
            PurchaseLine.Validate("PTSS Withholding Tax", HasWithholding);
            if not WithholdingTaxCodes.Get(Withholding1) or not WithholdingTaxCodes.Get(Withholding2) then begin
                SSLib.CreateWithholdingCode(WithholdingTaxCodes, true, Withholding1, Withholding2);
            end;

            WithholdingTaxCodes.Reset();
            WithholdingTaxCodes.Findset();
            if Withholding2 <> 0 then begin
                if WithholdingTaxCodes.Code = '' then begin
                    WithholdingTaxCodes.Next();
                    PurchaseHeader.Validate("PTSS Withholding Tax Code 1", WithholdingTaxCodes.Code);
                    WithholdingTaxCodes.Next();
                    PurchaseHeader.Validate("PTSS Withholding Tax Code 2", WithholdingTaxCodes.Code);
                end else begin
                    PurchaseHeader.Validate("PTSS Withholding Tax Code 1", WithholdingTaxCodes.Code);
                    WithholdingTaxCodes.Next();
                    PurchaseHeader.Validate("PTSS Withholding Tax Code 2", WithholdingTaxCodes.Code);
                end;
            end else begin
                if WithholdingTaxCodes.Code = '' then begin
                    WithholdingTaxCodes.Next();
                    PurchaseHeader.Validate("PTSS Withholding Tax Code 1", WithholdingTaxCodes.Code);
                end else begin
                    PurchaseHeader.Validate("PTSS Withholding Tax Code 1", WithholdingTaxCodes.Code);
                end;
            end;
        end;
        PurchaseLine.Modify(true);
        PurchaseHeader.Modify(true);
    end;

    procedure ChangeVATProdPostingGroupInItem(var Item: record Item; VATProdPostingCode: Code[20])
    begin
        Item.Validate("VAT Prod. Posting Group", VATProdPostingCode);
        Item.Modify(true);
    end;

    procedure PrintServiceQuote(ServiceHeader: Record "Service Header")
    begin
        Report.Run(report::"PTSS Service Quote (PT)", false, false, ServiceHeader);
    end;

    procedure PrintServiceOrder(ServiceHeader: Record "Service Header")
    begin
        Report.Run(report::"PTSS Service Order (PT)", false, false, ServiceHeader);
    end;

    procedure PrintServiceInvoice(ServiceHeader: Record "Service Header")
    begin
        Report.Run(report::"PTSS Service - Invoice (PT)", false, false, ServiceHeader);
    end;

    procedure PrintServiceCrMemo(ServiceHeader: Record "Service Header")
    begin
        Report.Run(report::"PTSS Service - Cr. Memo (PT)", false, false, ServiceHeader);
    end;

    procedure ChangeLastDateUsedInNoSeriesSalesHeader(LastDateUsedDate: Date; salesHeader: Record "Sales Header")
    var
        NoSeriesLine: Record "No. Series Line";
    begin
        NoSeriesLine.SetRange("Last No. Used", salesHeader."Last Posting No.");
        NoSeriesLine.FindFirst();
        NoSeriesLine.Validate("Last Date Used", LastDateUsedDate);
        NoSeriesLine.Modify();
    end;

    procedure CreateVATPostingSetupForStampdutySalesHeader(SalesHeader: Record "Sales Header")
    var
        SalesLine: REcord "Sales Line";
        VATPostSetup: Record "VAT Posting Setup";
        VATProdPostGrp: Record "VAT Product Posting Group";
        VATBusPostGrp: Record "VAT Business Posting Group";
    begin
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.FindLast();

        VATBusPostGrp.Get(SalesLine."VAT Bus. Posting Group");
        LibERM.CreateVATProductPostingGroup(VATProdPostGrp);

        SSLib.CreateVATPostingSetupLineWithVatPercentage(VATPostSetup, VATProdPostGrp, VATBusPostGrp, VATPostSetup."PTSS SAF-T PT VAT Code"::"Stamp Duty");
        SalesLine.Validate("VAT Prod. Posting Group", VATProdPostGrp.Code);
        SalesLine.Modify();
    end;

    procedure AutomaticSettlementCM(AutomaticSettlementCM: Boolean)
    var
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
    begin
        SalesReceivablesSetup.Get();
        SalesReceivablesSetup.Validate("PTSS Automatic Settlement CM", AutomaticSettlementCM);
        SalesReceivablesSetup.Modify();
    end;

    procedure AddBPStatisticToCustomer(BPStatistic: Record "PTSS BP Statistic"; var customer: Record customer)
    begin
        customer.Validate("PTSS BP Statistic Code", BPStatistic.code);
        customer.Modify(true);
    end;

    procedure AddBPStatisticToVendor(BPStatistic: Record "PTSS BP Statistic"; var Vendor: Record Vendor)
    begin
        Vendor.Validate("PTSS BP Statistic Code", BPStatistic.code);
        Vendor.Modify(true);
    end;

    procedure UpdateWithholdingDocumentLinePurch(var PurchaseHeader: Record "Purchase Header"; IsWithholding: Boolean; DocumentLine: Text; DocWith2WithholdingCodes: Boolean; WithholdingPayment: Boolean)
    var
        PurchaseLine: Record "Purchase Line";
        PurchaseDocLine: Integer;
        WithholdingTaxCodes: Record "PTSS Withholding Tax Codes";
    begin
        WithholdingTaxCodes.Reset();
        WithholdingTaxCodes.Findset();
        if (PurchaseHeader."PTSS Withholding Tax Code 1" = '') or (PurchaseHeader."PTSS Withholding Tax Code 2" = '') then begin
            if DocWith2WithholdingCodes then begin
                if WithholdingTaxCodes.Code = '' then begin
                    if PurchaseHeader."PTSS Withholding Tax Code 1" = '' then begin
                        WithholdingTaxCodes.Next();
                        PurchaseHeader.Validate("PTSS Withholding Tax Code 1", WithholdingTaxCodes.Code);
                    end;
                    if PurchaseHeader."PTSS Withholding Tax Code 2" = '' then begin
                        WithholdingTaxCodes.Next();
                        PurchaseHeader.Validate("PTSS Withholding Tax Code 2", WithholdingTaxCodes.Code);
                    end;
                end else begin
                    if PurchaseHeader."PTSS Withholding Tax Code 1" = '' then begin
                        PurchaseHeader.Validate("PTSS Withholding Tax Code 1", WithholdingTaxCodes.Code);
                    end;
                    if PurchaseHeader."PTSS Withholding Tax Code 2" = '' then begin
                        WithholdingTaxCodes.Next();
                        PurchaseHeader.Validate("PTSS Withholding Tax Code 2", WithholdingTaxCodes.Code);
                    end;
                end;
            end else begin
                if WithholdingTaxCodes.Code = '' then begin
                    if PurchaseHeader."PTSS Withholding Tax Code 1" = '' then begin
                        WithholdingTaxCodes.Next();
                        PurchaseHeader.Validate("PTSS Withholding Tax Code 1", WithholdingTaxCodes.Code);
                    end;
                end else begin
                    if PurchaseHeader."PTSS Withholding Tax Code 1" = '' then begin
                        PurchaseHeader.Validate("PTSS Withholding Tax Code 1", WithholdingTaxCodes.Code);
                    end;
                end;
            end;
        end;
        PurchaseHeader.Validate("PTSS Withholding Payment", WithholdingPayment);
        Evaluate(PurchaseDocLine, DocumentLine + '0000');
        PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", PurchaseDocLine);
        PurchaseLine.validate("PTSS Withholding Tax", IsWithholding);
        PurchaseLine.modify(true);
        PurchaseHeader.Modify(true);
    end;

    procedure ChangeBooleansInSalesCreditMemo(DoNotCommunicate: Boolean; CreditInvoice: Boolean; IntegrationSeries: Boolean; RecoverySeries: Boolean; DefaultNos: Boolean; ManualNos: Boolean; DateOrder: Boolean)
    var
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
        NoSeries: Record "No. Series";
    begin
        SalesReceivablesSetup.Get();
        SalesReceivablesSetup.Validate("Credit Memo Nos.", CreateNoSeries(false, false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" ", DoNotCommunicate, CreditInvoice, IntegrationSeries, RecoverySeries, DefaultNos, ManualNos, DateOrder));
        SalesReceivablesSetup.Modify();
    end;

    procedure SalesHeaderPrepaymentInformation(var SalesHeader: Record "Sales Header"; PrepaymentPercentage: Decimal; PrepaymentDueDate: Date; PrepmtPaymentDiscountPercentage: Decimal; PrepmtPmtDiscountDate: Date; PrepmtPaymentTermsCode: Text; CompressPrepayment: Boolean)
    begin
        SalesHeader.Validate("Prepayment %", PrepaymentPercentage);
        SalesHeader.Validate("Prepayment Due Date", PrepaymentDueDate);
        SalesHeader.Validate("Prepmt. Payment Discount %", PrepmtPaymentDiscountPercentage);
        SalesHeader.Validate("Prepmt. Pmt. Discount Date", PrepmtPmtDiscountDate);
        SalesHeader.Validate("Prepmt. Payment Terms Code", PrepmtPaymentTermsCode);
        SalesHeader.Validate("Compress Prepayment", CompressPrepayment);
        SalesHeader.Modify(true);
    end;

    procedure CreateNPostMultipleSimpleSalesInvoice(NumberOfOrders: Integer; SalesDocumentType: Enum "Sales Document Type"; Customer: record Customer; Item: record Item)
    var
        SalesHeader: Record "Sales Header";
        VATPostSetup: Record "VAT Posting Setup";
    begin
        repeat
            SSLib.CreateSalesDocSimpleBillToDefaultCustomer(SalesHeader, SalesDocumentType, Enum::"Sales Bill-to Options"::"Default (Customer)", Customer."No.");
            SSLib.CreateSalesLineWithDifferentDiscountAndVATTax(SalesHeader, Enum::"Sales Line Type"::Item, Item, 1, Customer, VATPostSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate", 0, 15);
            SSLib.PostSalesDocument(SalesHeader, true, true);
            NumberOfOrders -= 1;
        until NumberOfOrders = 0;
    end;

    procedure ChangeUserSettings(Workdate: Date)
    var
        UserSettings: Record "User Settings";
        UserSettingsPage: TestPage "User Settings";
    begin
        UserSettingsPage.OpenEdit();
        UserSettingsPage."Work Date".SetValue(Workdate);
        UserSettingsPage.OK().Invoke();
    end;

    procedure RegisterMultipleCustPaymentWithCashReceiptJournal(Customer: Record Customer)
    var
        CashReceiptJournalPage: TestPage "Cash Receipt Journal";
        PostedSalesInvoice: Record "Sales Invoice Header";
        GLAcc: Record "G/L Account";
        GenJournalLine: Record "Gen. Journal Line";
        ApplyCustomerEntries: TestPage "Apply Customer Entries";
        count: Integer;
        DocumentNo: Code[20];
    begin
        count := 0;
        DocumentNo := LibUti.GenerateRandomAlphabeticText(9, 1);
        CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);

        PostedSalesInvoice.setrange("Bill-to Customer No.", Customer."No.");
        if PostedSalesInvoice.FindSet() then begin
            CashReceiptJournalPage.OpenEdit();
            repeat
                if count <> 0 then begin
                    CashReceiptJournalPage.New();
                end;

                CashReceiptJournalPage."Document No.".SetValue(DocumentNo);
                CashReceiptJournalPage."Document Type".SetValue(Enum::"Gen. Journal Document Type"::Payment);
                CashReceiptJournalPage."Account Type".SetValue(Enum::"Gen. Journal Account Type"::Customer);
                CashReceiptJournalPage."Account No.".SetValue(Customer."No.");
                CashReceiptJournalPage.Description.SetValue(LibUti.GenerateRandomText(4));
                CashReceiptJournalPage."Bal. Account No.".SetValue(GLAcc."No.");
                CashReceiptJournalPage."Apply Entries".Invoke();

                GenJournalLine.SetRange("Document No.", CashReceiptJournalPage."Document No.".Value);
                if GenJournalLine.FindSet() then begin
                    repeat
                        GenJournalLine.Validate("Bal. Gen. Bus. Posting Group", '');
                        GenJournalLine.Validate("Bal. Gen. Prod. Posting Group", '');
                        GenJournalLine.Validate("Bal. VAT Bus. Posting Group", '');
                        GenJournalLine.Validate("Bal. VAT Prod. Posting Group", '');
                        GenJournalLine.Modify();
                    until GenJournalLine.Next() = 0;
                end;
                count += 1;
            until PostedSalesInvoice.Next() = 0;
            CashReceiptJournalPage.Post.Invoke();
        end;
    end;

    procedure CashReceiptNewLineAndPutRecord(var "Cash Receipt Journal": TestPage "Cash Receipt Journal"; var "General Journal Line": Record "Gen. Journal Line")
    begin
        "Cash Receipt Journal".New();
        "Cash Receipt Journal"."Posting Date".SetValue("General Journal Line"."Posting Date");
        "Cash Receipt Journal"."Document No.".SetValue("General Journal Line"."Document No.");
        "Cash Receipt Journal"."Account Type".SetValue("General Journal Line"."Account Type");
        "Cash Receipt Journal"."Account No.".SetValue("General Journal Line"."Account No.");
        "Cash Receipt Journal".Description.SetValue("General Journal Line".Description);
        "Cash Receipt Journal"."Bal. Account No.".SetValue("General Journal Line"."Bal. Account No.");
        "Cash Receipt Journal"."Bal. Account Type".SetValue("General Journal Line"."Bal. Account Type");
        "Cash Receipt Journal"."PTSS Posting Group".SetValue("General Journal Line"."Posting Group");
        "Cash Receipt Journal".Amount.SetValue("General Journal Line".Amount);
        //"Cash Receipt Journal".GoToRecord("General Journal Line");
    end;

    procedure ChanceCustomerPostingGroupInGenJournalLine(var GenJournalLine: Record "Gen. Journal Line"; CustomerPostingGroup: Record "Customer Posting Group")
    begin
        GenJournalLine.Validate("Posting Group", CustomerPostingGroup.Code);
        GenJournalLine.Modify();
    end;

    procedure ChangeCompanyInfo(TaxonomyReference: Enum "PTSS Taxonomy Reference Enum")
    var
        CompanyInformation: Record "Company Information";
    begin
        CompanyInformation.get();
        CompanyInformation.Validate("PTSS Taxonomy Reference", TaxonomyReference);
        CompanyInformation.Modify(true);
    end;

    procedure CreateNoSeries(SAFT: Boolean; GTAT: Boolean; WD: Boolean; IsReceipt: Boolean; DocType: Option; DoNotCommunicate: Boolean; CreditInvoice: Boolean; IntegrationSeries: Boolean; RecoverySeries: Boolean; DefaultNos: Boolean; ManualNos: Boolean; DateOrder: Boolean): Code[20]
    var
        NoSeries: Record "No. Series";
        NoSeriesText: Text;
        NoSeriesLine: Record "No. Series Line";
        RecRef: RecordRef;
        Error: Label 'SAFT and GTAT cannot be both true';
    begin
        NoSeriesText := LibUti.GenerateRandomCode(1, 308);
        NoSeries.Init();
        NoSeries.Validate(Code, NoSeriesText);
        NoSeries.Insert(true);

        if SAFT and GTAT then
            Error(Error);
        if SAFT then
            NoSeries.Validate("PTSS SAF-T Invoice Type", DocType);
        if GTAT then
            NoSeries.Validate("PTSS GTAT Document Type", DocType);
        if WD then
            NoSeries.Validate("PTSS SAF-T Working Doc Type", DocType);
        if IsReceipt then
            NoSeries.Validate("PTSS Receipt Type", DocType);

        if NoSeries."PTSS Do Not Communicate" <> DoNotCommunicate then begin
            NoSeries.Validate("PTSS Do Not Communicate", DoNotCommunicate);
        end;
        if NoSeries."PTSS Credit Invoice" <> CreditInvoice then begin
            NoSeries.Validate("PTSS Credit Invoice", CreditInvoice);
        end;
        if NoSeries."PTSS Integration Series" <> IntegrationSeries then begin
            NoSeries.Validate("PTSS Integration Series", IntegrationSeries);
        end;
        if NoSeries."PTSS Recovery Series" <> RecoverySeries then begin
            NoSeries.Validate("PTSS Recovery Series", RecoverySeries);
        end;
        if NoSeries."Default Nos." <> DefaultNos then begin
            NoSeries.Validate("Default Nos.", DefaultNos);
        end;
        if NoSeries."Date Order" <> DateOrder then begin
            NoSeries.Validate("Date Order", DateOrder);
        end;
        NoSeries.Modify(true);

        NoSeriesLine.Init();
        NoSeriesLine."Starting Date" := Today;
        NoSeriesLine.Validate("Series Code", NoSeries.Code);
        RecRef.GetTable(NoSeriesLine);
        NoSeriesLine.Validate("Line No.", LibUti.GetNewLineNo(RecRef, NoSeriesLine.FieldNo("Line No.")));
        if RecoverySeries then begin
            noseriesline.Validate("PTSS Series Type", 3);
        end;
        NoSeriesLine.Insert(true);

        if (NoSeriesText + '0001') = '' then
            NoSeriesLine.Validate("Starting No.", PadStr(InsStr(NoSeries.Code, '00000000', 3), 10))
        else
            NoSeriesLine.Validate("Starting No.", NoSeriesText + '0001');

        if (NoSeriesText + '9999') = '' then
            NoSeriesLine.Validate("Ending No.", PadStr(InsStr(NoSeries.Code, '99999999', 3), 10))
        else
            NoSeriesLine.Validate("Ending No.", NoSeriesText + '9999');

        NoSeriesLine.validate("PTSS SAF-T No. Series Del.", StrLen(NoSeriesText));

        noseriesline.Validate("PTSS AT Validation Code", 'D5P' + LibUti.GenerateRandomAlphabeticText(8, 0));
        NoSeriesLine.Modify();

        exit(NoSeries.Code);
    end;

    procedure ModifyCountryRegion(Customer: Record Customer)
    var
        CountryRegion: Record "Country/Region";
    begin
        CountryRegion.Get(Customer."Country/Region Code");
        CountryRegion.Validate("ISO Code", 'AB');
        CountryRegion.Modify(true);
    end;

    procedure UpdateLineWithLocation(var SalesHeader: Record "Sales Header"; Amount: Integer; UnitPrice: Decimal; QtyToInvoice: Integer; Location: Record Location)
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.FindFirst();
        SalesLine.Validate("Location Code", Location.Code);
        SalesLine.validate(amount, amount);
        SalesLine.Validate("Unit Price", UnitPrice);
        SalesLine.Validate("Qty. to Invoice", QtyToInvoice);
        SalesLine.Modify();
    end;

    procedure UpdateLineService(var ServiceHeader: Record "Service Header"; Amount: Integer; UnitPrice: Decimal; QtyToInvoice: Integer)
    var
        ServiceLine: Record "Service Line";
    begin
        ServiceLine.SetRange("Document No.", ServiceHeader."No.");
        ServiceLine.FindFirst();
        ServiceLine.validate(amount, amount);
        ServiceLine.Validate("Unit Price", UnitPrice);
        ServiceLine.Modify();
    end;

    procedure UpdateLineServiceWithLocation(var ServiceHeader: Record "Service Header"; Amount: Integer; UnitPrice: Decimal; QtyToInvoice: Integer; Location: Record Location)
    var
        ServiceLine: Record "Service Line";
    begin
        ServiceLine.SetRange("Document No.", ServiceHeader."No.");
        ServiceLine.FindFirst();
        ServiceLine.validate("Location code", Location.code);
        ServiceLine.validate(amount, amount);
        ServiceLine.Validate("Unit Price", UnitPrice);
        ServiceLine.Modify();
    end;

    procedure UpdateHeaderPostingDate(var SalesHeader: Record "Sales Header"; Date: Date)
    begin
        SalesHeader.Validate("Posting Date", Date);
        SalesHeader.Modify();
    end;

    procedure UpdateCustomerWithholdingCode(var Customer: Record Customer; var WithholdingCode: Record "PTSS Withholding Tax Codes"; TwoWithholdingCodes: Boolean)
    begin
        if WithholdingCode.FindSet() then begin
            Customer.Validate("PTSS Withholding Payment", true);
            Customer.Validate("PTSS Withholding Tax Code", WithholdingCode.code);
            if TwoWithholdingCodes then begin
                WithholdingCode.Next();
                Customer.Validate("PTSS Withholding Tax Code 2", WithholdingCode.code);
            end;
            Customer.Modify(true);
        end;
    end;

    procedure UpdateWithholdingDocumentLine(var SalesHeader: Record "Sales Header"; IsWithholding: Boolean; DocumentLine: Text; DocWith2WithholdingCodes: Boolean; WithholdingPayment: Boolean)
    var
        SalesLine: Record "Sales Line";
        SalesDocLine: Integer;
        WithholdingTaxCodes: Record "PTSS Withholding Tax Codes";
    begin
        WithholdingTaxCodes.Reset();
        WithholdingTaxCodes.Findset();
        if (SalesHeader."PTSS Withholding Tax Code" = '') or (SalesHeader."PTSS Withholding Tax Code 2" = '') then begin
            if DocWith2WithholdingCodes then begin
                if WithholdingTaxCodes.Code = '' then begin
                    if SalesHeader."PTSS Withholding Tax Code" = '' then begin
                        WithholdingTaxCodes.Next();
                        SalesHeader.Validate("PTSS Withholding Tax Code", WithholdingTaxCodes.Code);
                    end;
                    if SalesHeader."PTSS Withholding Tax Code 2" = '' then begin
                        WithholdingTaxCodes.Next();
                        SalesHeader.Validate("PTSS Withholding Tax Code 2", WithholdingTaxCodes.Code);
                    end;
                end else begin
                    if SalesHeader."PTSS Withholding Tax Code" = '' then begin
                        SalesHeader.Validate("PTSS Withholding Tax Code", WithholdingTaxCodes.Code);
                    end;
                    if SalesHeader."PTSS Withholding Tax Code 2" = '' then begin
                        WithholdingTaxCodes.Next();
                        SalesHeader.Validate("PTSS Withholding Tax Code 2", WithholdingTaxCodes.Code);
                    end;
                end;
            end else begin
                if WithholdingTaxCodes.Code = '' then begin
                    if SalesHeader."PTSS Withholding Tax Code" = '' then begin
                        WithholdingTaxCodes.Next();
                        SalesHeader.Validate("PTSS Withholding Tax Code", WithholdingTaxCodes.Code);
                    end;
                end else begin
                    if SalesHeader."PTSS Withholding Tax Code" = '' then begin
                        SalesHeader.Validate("PTSS Withholding Tax Code", WithholdingTaxCodes.Code);
                    end;
                end;
            end;
        end;
        SalesHeader.Validate("PTSS Withholding Payment", WithholdingPayment);
        Evaluate(SalesDocLine, DocumentLine + '0000');
        SalesLine.Get(SalesHeader."Document Type", SalesHeader."No.", SalesDocLine);
        SalesLine.validate("PTSS Withholding Tax", IsWithholding);
        SalesLine.modify(true);
        SalesHeader.Modify(true);
    end;

    procedure ChangeWithholdingDocumentFields(var SalesHeader: Record "Sales Header"; WithholdingPayment: Boolean; WithholdingTaxesCodes: Boolean; WithholdingLine: Boolean)
    var
        SalesLine: Record "Sales Line";
    begin
        SalesHeader.Validate("PTSS Withholding Payment", WithholdingPayment);
        if not WithholdingTaxesCodes then begin
            SalesHeader.Validate("PTSS Withholding Tax Code", '');
            SalesHeader.Validate("PTSS Withholding Tax Code 2", '');
        end;
        SalesLine.SetRange(SalesLine."Document Type", SalesHeader."Document Type");
        SalesLine.SetRange(SalesLine."Document No.", SalesHeader."No.");
        SalesLine.SetRange(SalesLine."PTSS Withholding Tax", true);
        if SalesLine.FindSet() then begin
            repeat
                SalesLine.Validate("PTSS Withholding Tax", WithholdingLine);
            until SalesLine.Next() = 0;
            SalesLine.Modify(true);
        end;
        SalesHeader.Modify(true);
    end;

    procedure UpdateIncrementedByNo(var NoSeries: Record "No. Series"; var NoSeriesLine: Record "No. Series Line")
    var
    begin
        NoSeriesLine.SetRange(NoSeriesLine."Series Code", NoSeries.Code);
        if NoSeriesLine.FindSet() then begin
            NoSeriesLine.Validate("Increment-by No.", (Random(99) + 1));
            NoSeriesLine.Modify();
        end
    end;

    procedure GenerateNDocTypeDocuments(DocType: Text; NoOfDoc: Integer; Customer: Record Customer; Vendor: Record Vendor; Item: Record Item; DateDoc: Date)
    var
        PurchHeader: Record "Purchase Header";
        SalesHeader: Record "Sales Header";
        ToGov, ToCompany, AppliedVAT, DeductVAT, ReverseCharge : Record "G/L Account";
        GenBusPostingGroup: Record "Gen. Business Posting Group";
        GenProdPostingGroup: Record "Gen. Product Posting Group";
        VatPostSetup: Record "VAT Posting Setup";
        SalesLine: Record "Sales Line";

    begin
        repeat
            SSLib.CreateSalesDoc(SalesHeader, Enum::"Sales Document Type"::Invoice, Item, 10, Customer."No.", ToGov, ToCompany, AppliedVAT, DeductVAT, ReverseCharge, GenBusPostingGroup, GenProdPostingGroup, 23, 23, 0, VatPostSetup."VAT Calculation Type"::"Normal VAT", VatPostSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate", VatPostSetup."PTSS SAF-T PT VAT Type Desc."::"VAT Portugal Mainland", false);
            UpdateHeaderPostingDate(SalesHeader, DateDoc);
            UpdateLine(SalesHeader, Random(10), random(999), 10);
            SSLib.PostSalesDocument(SalesHeader, true, true);
            Clear(SalesHeader);

            NoOfDoc -= 1;
        until NoOfDoc = 0;
    end;

    procedure UpdateLinePurch(var PurchHeader: Record "Purchase Header"; QtyToInvoice: Decimal)
    var
        PurchLine: Record "Purchase Line";
    begin
        PurchLine.SetRange("Document No.", PurchHeader."No.");
        PurchLine.FindFirst();
        PurchLine.Validate("VAT Base Amount", 5);
        PurchLine.Validate("Prepmt. VAT Amount Inv. (LCY)", 5);
        PurchLine.Validate("Qty. per Unit of Measure", 1);
        PurchLine.Validate("Direct Unit Cost", 10);
        PurchLine.Validate("Line Amount", 5);
        PurchLine.Validate(Amount, 5);
        PurchLine.Validate("Unit Price (LCY)", 5.0);
        PurchLine.Modify(true);
    end;

    procedure UpdateLinePurchWithLocation(var PurchHeader: Record "Purchase Header"; QtyToInvoice: Decimal; Location: Record Location)
    var
        PurchLine: Record "Purchase Line";
    begin
        PurchLine.SetRange("Document No.", PurchHeader."No.");
        PurchLine.FindFirst();
        PurchLine.validate("Location Code", Location.code);
        PurchLine.Validate("VAT Base Amount", 5);
        PurchLine.Validate("Prepmt. VAT Amount Inv. (LCY)", 5);
        PurchLine.Validate("Qty. per Unit of Measure", 1);
        PurchLine.Validate("Direct Unit Cost", 10);
        PurchLine.Validate("Line Amount", 5);
        PurchLine.Validate(Amount, 5);
        PurchLine.Validate("Unit Price (LCY)", 5.0);
        PurchLine.Modify(true);
    end;

    procedure UpdateWorkingDocumentDocLineAmount(WorkingDocumentsHeader: Record "PTSS Working Documents Header")
    var
        WorkingDocumentsLine: Record "PTSS Working Documents Line";
    begin
        WorkingDocumentsLine.SetRange("Document No.", WorkingDocumentsHeader."No.");
        WorkingDocumentsLine.SetRange(Type, Enum::"Sales Line Type"::Item);
        if WorkingDocumentsLine.FindFirst() then begin
            WorkingDocumentsLine."Line Amount" := 99999;
            WorkingDocumentsLine.Modify();
        end;
    end;

    procedure ChangeSalesReportV2(DocType: Enum Microsoft.Foundation.Reporting."Report Selection Usage"; ReportID: Integer)
    var
        RepSelectionSalesPage: TestPage "Report Selection - Sales";
        ReportSelections: Record "Report Selections";
    begin
        ReportSelections.get(DocType, 1);
        ReportSelections.Validate("Report ID", ReportID);
        ReportSelections.modify();
    end;

    internal procedure SetupNoSeriesForServices()
    var
        ServiceMgtSetup: Record "Service Mgt. Setup";
        NoSeries: Record "No. Series";
    begin
        ServiceMgtSetup.get();
        ServiceMgtSetup.Validate("Service Order Nos.", CreateNoSeries(false, false, false, false, NoSeries."PTSS GTAT Document Type"::" ", false, false, false, false, true, false, false));
        ServiceMgtSetup.Validate("Service Quote Nos.", CreateNoSeries(false, false, false, false, NoSeries."PTSS GTAT Document Type"::" ", false, false, false, false, true, false, false));
        ServiceMgtSetup.Validate("Service Invoice Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        ServiceMgtSetup.Validate("Posted Service Invoice Nos.", SSLib.CreateNoSeries(true, false, false, NoSeries."PTSS SAF-T Invoice Type"::"FT"));
        ServiceMgtSetup.Validate("Service Credit Memo Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        ServiceMgtSetup.Validate("Posted Serv. Credit Memo Nos.", SSLib.CreateNoSeries(true, false, false, NoSeries."PTSS SAF-T Invoice Type"::"NC"));
        ServiceMgtSetup.Validate("Posted Service Shipment Nos.", SSLib.CreateNoSeries(false, true, false, NoSeries."PTSS GTAT Document Type"::"GT"));
        ServiceMgtSetup.Modify();
    end;

    internal procedure SetupNoSeriesForInventorySetup()
    var
        InventorySetup: Record "Inventory Setup";
        NoSeries: Record "No. Series";
    begin
        InventorySetup.get();
        InventorySetup.Validate("Transfer Order Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS GTAT Document Type"::" "));
        InventorySetup.Validate("Posted Transfer Shpt. Nos.", SSLib.CreateNoSeries(false, true, false, NoSeries."PTSS GTAT Document Type"::"GT"));
        InventorySetup.Modify();
    end;

    procedure SetupNoSeriesForSales()
    var
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        SalesReceivablesSetup.Get();
        SalesReceivablesSetup.Validate("Invoice Nos.", CreateNoSeries(false, false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" ", false, false, false, false, true, false, true));
        SalesReceivablesSetup.Validate("Posted Shipment Nos.", SSLib.CreateNoSeries(false, true, false, NoSeries."PTSS GTAT Document Type"::GT));
        SalesReceivablesSetup.Validate("Posted Invoice Nos.", CreateNoSeries(true, false, false, false, NoSeries."PTSS SAF-T Invoice Type"::FT, false, false, false, false, true, false, true));
        SalesReceivablesSetup.Validate("Order Nos.", CreateNoSeries(false, false, false, false, NoSeries."PTSS GTAT Document Type"::" ", false, false, false, false, true, false, false));
        SalesReceivablesSetup.Validate("Credit Memo Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        SalesReceivablesSetup.Validate("Posted Credit Memo Nos.", SSLib.CreateNoSeries(true, false, false, NoSeries."PTSS SAF-T Invoice Type"::"NC"));
        SalesReceivablesSetup.Validate("PTSS Posted Debit Memo Nos.", SSLib.CreateNoSeries(true, false, false, NoSeries."PTSS SAF-T Invoice Type"::"ND"));
        SalesReceivablesSetup.Validate("PTSS Debit Memo Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        SalesReceivablesSetup.Validate("Quote Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        SalesReceivablesSetup.Validate("Return Order Nos.", SSLib.CreateNoSeries(true, false, false, NoSeries."PTSS SAF-T Invoice Type"::NC));
        SalesReceivablesSetup.Validate("Posted Return Receipt Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        SalesReceivablesSetup.Validate("Fin. Chrg. Memo Nos.", CreateNoSeries(false, false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" ", false, false, false, false, true, false, false));
        SalesReceivablesSetup.validate("Blanket Order Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        SalesReceivablesSetup.Validate("PTSS Posted Fin. Chrg. M. Nos.", SSLib.CreateNoSeries(true, false, false, NoSeries."PTSS SAF-T Invoice Type"::ND));
        SalesReceivablesSetup.Validate("Issued Fin. Chrg. M. Nos.", SSLib.CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::FS));
        SalesReceivablesSetup.Validate("Posted Prepmt. Inv. Nos.", SSLib.CreateNoSeries(true, false, false, NoSeries."PTSS SAF-T Invoice Type"::FT));
        SalesReceivablesSetup.Validate("Posted Prepmt. Cr. Memo Nos.", SSLib.CreateNoSeries(true, false, false, NoSeries."PTSS SAF-T Invoice Type"::NC));
        SSLib.CreateNoSeriesV2(noSeries, NoSeriesLine, false, false, false, true, NoSeries."PTSS Receipt Type"::"PTSS Other Receipts");
        SalesReceivablesSetup.Validate("PTSS Receipt Nos.", noSeries.Code);
        SalesReceivablesSetup.Modify(true);
    end;

    procedure ValidateSequenceNoSeriesPurch(NumberOfOrders: Integer; PurchDocumentType: Enum "Purchase Document Type")
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        PurchasesPayablesSetup: Record "Purchases & Payables Setup";
        PreviousDocumentNo, NextDocumentNo : Integer;
        PurchaseHeader: Record "Purchase Header";
        PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
        PurchInvHeader: REcord "Purch. Inv. Header";
    begin
        PurchasesPayablesSetup.Get();

        case PurchDocumentType of
            PurchDocumentType::"Return Order":
                begin
                    NoSeries.Get(PurchasesPayablesSetup."Return Order Nos.");
                    NoSeriesLine.Get(NoSeries.Code, 10000);

                    PurchCrMemoHdr.RESET;
                    PurchCrMemoHdr.setrange("Return Order No. Series", NoSeriesLine."Series Code");
                    IF PurchCrMemoHdr.FindSet() THEN BEGIN
                        REPEAT
                            PreviousDocumentNo := NextDocumentNo;
                            Evaluate(NextDocumentNo, CopyStr(PurchCrMemoHdr."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1, StrLen(NoSeriesLine."PTSS SAFT-T Sequential No.")));
                            Verify.NoSeriesIsSequential(PreviousDocumentNo, NextDocumentNo);
                        UNTIL PurchCrMemoHdr.Next() = 0;
                    END;
                end;
            PurchDocumentType::Invoice:
                begin
                    NoSeries.Get(PurchasesPayablesSetup."Posted Invoice Nos.");
                    NoSeriesLine.Get(NoSeries.Code, 10000);

                    PurchCrMemoHdr.RESET;
                    PurchInvHeader.SetRange("No. Series", NoSeries.Code);
                    IF PurchInvHeader.FindSet() THEN BEGIN
                        REPEAT
                            PreviousDocumentNo := NextDocumentNo;
                            Evaluate(NextDocumentNo, CopyStr(PurchInvHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1, StrLen(NoSeriesLine."PTSS SAFT-T Sequential No.")));
                            Verify.NoSeriesIsSequential(PreviousDocumentNo, NextDocumentNo);
                        UNTIL PurchInvHeader.Next() = 0;
                    END;
                end;
        end;
    end;

    procedure ValidateSequenceNoSeriesSales(NumberOfOrders: Integer; SalesDocumentType: Enum "Sales Document Type"; IsPrepayment: Boolean; IsIntegretion: Boolean; IsRecuperation: Boolean)
    var
        NoSeries, NoSeries2 : Record "No. Series";
        NoSeriesLine, NoSeriesLine2 : Record "No. Series Line";
        SalesRec: Record "Sales & Receivables Setup";
        PreviousDocumentNo, NextDocumentNo, Counter : Integer;
        SalesInvoiceHeader: Record "Sales invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        ReturnReceiptHeader: Record "Return Receipt Header";
        SalesHeader: Record "Sales Header";
    begin
        SalesRec.Get();

        case SalesDocumentType of
            SalesDocumentType::"Credit Memo":
                begin
                    NoSeries.Get(SalesRec."Posted Credit Memo Nos.");
                    NoSeriesLine.Get(NoSeries.Code, 10000);

                    if IsPrepayment then begin
                        NoSeries.Reset();
                        NoSeriesLine.Reset();
                        NoSeries.Get(SalesRec."Posted Prepmt. Cr. Memo Nos.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);
                    end;

                    if IsIntegretion then begin
                        NoSeries.Reset();
                        NoSeriesLine.Reset();
                        NoSeries.Get(SalesRec."PTSS Int. Cr.Memo Series No.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);
                    end;

                    SalesCrMemoHeader.RESET;
                    SalesCrMemoHeader.setrange("No. Series", NoSeriesLine."Series Code");
                    IF SalesCrMemoHeader.FindSet() THEN BEGIN
                        REPEAT
                            PreviousDocumentNo := NextDocumentNo;
                            Evaluate(NextDocumentNo, CopyStr(SalesCrMemoHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1, StrLen(NoSeriesLine."PTSS SAFT-T Sequential No.")));
                            Verify.NoSeriesIsSequential(PreviousDocumentNo, NextDocumentNo);
                        UNTIL SalesCrMemoHeader.Next() = 0;
                    END;
                end;
            SalesDocumentType::"Invoice":
                begin
                    NoSeries.Get(SalesRec."Posted Invoice Nos.");
                    NoSeriesLine.Get(NoSeries.Code, 10000);

                    if IsPrepayment then begin
                        NoSeries.Reset();
                        NoSeriesLine.Reset();
                        NoSeries.Get(SalesRec."Posted Prepmt. Inv. Nos.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);
                    end;

                    if IsIntegretion then begin
                        NoSeries.Reset();
                        NoSeriesLine.Reset();
                        NoSeries.Get(SalesRec."PTSS Int. Inv. Series No.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);
                    end;

                    SalesInvoiceHeader.RESET;
                    SalesInvoiceHeader.setrange("No. Series", NoSeriesLine."Series Code");
                    IF SalesInvoiceHeader.FindSet() THEN BEGIN
                        REPEAT
                            PreviousDocumentNo := NextDocumentNo;
                            Evaluate(NextDocumentNo, CopyStr(SalesInvoiceHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1, StrLen(NoSeriesLine."PTSS SAFT-T Sequential No.")));
                            Verify.NoSeriesIsSequential(PreviousDocumentNo, NextDocumentNo);
                        UNTIL SalesInvoiceHeader.Next() = 0;
                    END;
                end;
            SalesDocumentType::"PTSS Debit Memo":
                begin
                    NoSeries.Get(SalesRec."Posted invoice Nos.");
                    NoSeriesLine.Get(NoSeries.Code, 10000);

                    SalesinvoiceHeader.RESET;
                    SalesinvoiceHeader.setrange("PTSS Debit Memo", true);
                    IF SalesinvoiceHeader.FindSet() THEN BEGIN
                        REPEAT
                            PreviousDocumentNo := NextDocumentNo;
                            Evaluate(NextDocumentNo, CopyStr(SalesinvoiceHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1, StrLen(NoSeriesLine."PTSS SAFT-T Sequential No.")));
                            Verify.NoSeriesIsSequential(PreviousDocumentNo, NextDocumentNo);
                        UNTIL SalesinvoiceHeader.Next() = 0;
                    END;
                end;
            SalesDocumentType::"Return Order":
                begin
                    NoSeries.Get(SalesRec."Posted Return Receipt Nos.");
                    NoSeriesLine.Get(NoSeries.Code, 10000);

                    ReturnReceiptHeader.setrange("No. Series", NoSeriesLine."Series Code");
                    IF ReturnReceiptHeader.FindSet() THEN BEGIN
                        REPEAT
                            PreviousDocumentNo := NextDocumentNo;
                            Evaluate(NextDocumentNo, CopyStr(ReturnReceiptHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1, StrLen(NoSeriesLine."PTSS SAFT-T Sequential No.")));
                            Verify.NoSeriesIsSequential(PreviousDocumentNo, NextDocumentNo);
                        UNTIL ReturnReceiptHeader.Next() = 0;
                    END;
                end;
            SalesDocumentType::Order:
                begin
                    NoSeries.Get(SalesRec."Order Nos.");
                    NoSeriesLine.Get(NoSeries.Code, 10000);

                    SalesHeader.setrange("No. Series", NoSeries.Code);
                    IF SalesHeader.FindSet() THEN BEGIN
                        REPEAT
                            PreviousDocumentNo := NextDocumentNo;
                            Evaluate(NextDocumentNo, CopyStr(SalesHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1, StrLen(NoSeriesLine."PTSS SAFT-T Sequential No.")));
                            Verify.NoSeriesIsSequential(PreviousDocumentNo, NextDocumentNo);
                        UNTIL SalesHeader.Next() = 0;
                    END;
                end;
        end;
    end;

    procedure ValidateSequenceNoSeriesService(ServiceDocumentType: Enum "Service Document Type")
    var
        NoSeries, NoSeries2 : Record "No. Series";
        NoSeriesLine, NoSeriesLine2 : Record "No. Series Line";
        ServiceMgtSetup: Record "Service Mgt. Setup";
        PreviousDocumentNo, NextDocumentNo : Integer;
        ServiceHeader: Record "Service Header";
        ServiceInvoiceHeader: Record "Service Invoice Header";
        ServiceCrMemoHeader: Record "Service Cr.Memo Header";
        ReturnReceiptHeader: Record "Return Receipt Header";
    begin
        ServiceMgtSetup.Get();

        case ServiceDocumentType of
            ServiceDocumentType::"Credit Memo":
                begin
                    NoSeries.Get(ServiceMgtSetup."Posted Serv. Credit Memo Nos.");
                    NoSeriesLine.Get(NoSeries.Code, 10000);

                    ServiceCrMemoHeader.RESET;
                    ServiceCrMemoHeader.setrange("No. Series", NoSeriesLine."Series Code");
                    IF ServiceCrMemoHeader.FindSet() THEN BEGIN
                        REPEAT
                            PreviousDocumentNo := NextDocumentNo;
                            Evaluate(NextDocumentNo, CopyStr(ServiceCrMemoHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1, StrLen(NoSeriesLine."PTSS SAFT-T Sequential No.")));
                            Verify.NoSeriesIsSequential(PreviousDocumentNo, NextDocumentNo);
                        UNTIL ServiceCrMemoHeader.Next() = 0;
                    END;
                end;
            ServiceDocumentType::"Invoice":
                begin
                    NoSeries.Get(ServiceMgtSetup."Posted Service Invoice Nos.");
                    NoSeriesLine.Get(NoSeries.Code, 10000);

                    ServiceInvoiceHeader.RESET;
                    ServiceInvoiceHeader.setrange("No. Series", NoSeriesLine."Series Code");
                    IF ServiceInvoiceHeader.FindSet() THEN BEGIN
                        REPEAT
                            PreviousDocumentNo := NextDocumentNo;
                            Evaluate(NextDocumentNo, CopyStr(ServiceInvoiceHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1, StrLen(NoSeriesLine."PTSS SAFT-T Sequential No.")));
                            Verify.NoSeriesIsSequential(PreviousDocumentNo, NextDocumentNo);
                        UNTIL ServiceInvoiceHeader.Next() = 0;
                    END;
                end;
        end;
    end;

    procedure ValidateSequenceNoSeriesWorkingDocument(NumberOfOrders: Integer; WDDocumentType: Enum "PTSS SAF-T Working Doc Type Enum")
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        SalesRec: Record "Sales & Receivables Setup";
        ServiceMgtSetup: Record "Service Mgt. Setup";
        PreviousDocumentNo, NextDocumentNo, Counter : Integer;
        WorkingDocumentsHeader: Record "PTSS Working Documents Header";
    begin
        Counter := 0;

        SalesRec.Get();
        ServiceMgtSetup.Get();

        case WDDocumentType of
            WDDocumentType::"OR":
                begin
                    if not NoSeries.Get(SalesRec."PTSS WD Sales Quote Nos.") then begin
                        NoSeries.Get(ServiceMgtSetup."PTSS WD Service Quote Nos.")
                    end;
                    NoSeriesLine.Get(NoSeries.Code, 10000);
                    WorkingDocumentsHeader.SetRange("Document Type", WorkingDocumentsHeader."Document Type"::Quote);
                end;
            WDDocumentType::"NE":
                begin
                    if not NoSeries.Get(SalesRec."PTSS WD Sales Order Nos.") then begin
                        NoSeries.Get(ServiceMgtSetup."PTSS WD Service Order Nos.");
                    end;
                    NoSeriesLine.Get(NoSeries.Code, 10000);
                    WorkingDocumentsHeader.SetRange("Document Type", WorkingDocumentsHeader."Document Type"::Order);
                end;
            WDDocumentType::PF:
                begin
                    NoSeries.Get(SalesRec."PTSS WD Proforma Invoice Nos.");
                    NoSeriesLine.Get(NoSeries.Code, 10000);
                    WorkingDocumentsHeader.SetRange("Document Type", WorkingDocumentsHeader."Document Type"::"ProForma Invoice");
                end;
            WDDocumentType::OU:
                begin
                    NoSeries.Get(SalesRec."PTSS WD Blank. Sales Order Nos");
                    NoSeriesLine.Get(NoSeries.Code, 10000);
                    WorkingDocumentsHeader.SetRange("Document Type", WorkingDocumentsHeader."Document Type"::"Blanket Order");
                end;
        end;

        IF WorkingDocumentsHeader.FindSet() THEN BEGIN
            REPEAT
                PreviousDocumentNo := NextDocumentNo;
                Evaluate(NextDocumentNo, CopyStr(WorkingDocumentsHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1, StrLen(NoSeriesLine."PTSS SAFT-T Sequential No.")));
                Verify.NoSeriesIsSequential(PreviousDocumentNo, NextDocumentNo);
            UNTIL WorkingDocumentsHeader.Next() = 0;
        END else begin
            error('Working Document Not Found');
        end;
    end;

    procedure ValidateHashNoSales(NumberOfOrders: Integer; SalesDocumentType: Enum "Sales Document Type"; IsPrepayment: Boolean; IsIntegretion: Boolean; IsRecovery: Boolean)
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        SalesRec: Record "Sales & Receivables Setup";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        PreviousHashNo, NewHashtNo, LastHashUsed : Text;
        NoSeriesMgt: Codeunit "PTSS No. Series Management";
        SSHashDocType, SSHashNoSeries, SSHashDocNo : Code[100];
        SSHashAmountIncludingVAT: Decimal;
    begin
        SalesRec.Get();

        if (SalesDocumentType = SalesDocumentType::Invoice) or (SalesDocumentType = SalesDocumentType::"PTSS Debit Memo") then begin
            case SalesDocumentType of
                SalesDocumentType::Invoice:
                    begin
                        NoSeries.Get(SalesRec."Posted Invoice Nos.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);
                    end;
                SalesDocumentType::"PTSS Debit Memo":
                    begin
                        NoSeries.Get(SalesRec."PTSS Debit Memo Nos.");
                        NoSeriesLine.Get(NoSeries.Code, 10000);
                    end;
            end;

            if IsPrepayment then begin
                NoSeries.Reset();
                NoSeriesLine.Reset();
                NoSeries.Get(SalesRec."Posted Prepmt. Inv. Nos.");
                NoSeriesLine.Get(NoSeries.Code, 10000);
            end;

            if IsIntegretion then begin
                NoSeries.Reset();
                NoSeriesLine.Reset();
                NoSeries.Get(SalesRec."PTSS Int. Inv. Series No.");
                NoSeriesLine.Get(NoSeries.Code, 10000);
            end;

            if IsRecovery then begin
                NoSeries.Reset();
                NoSeriesLine.Reset();
                NoSeries.Get(SalesRec."PTSS Rec. Inv. Series No.");
                NoSeriesLine.Get(NoSeries.Code, 10000);
            end;

            SalesInvoiceHeader.RESET;
            SalesInvoiceHeader.setrange("No. Series", NoSeriesLine."Series Code");
            IF SalesInvoiceHeader.FindSet() THEN BEGIN
                REPEAT
                    NoSeriesMgt.GetAndValidateNoSeriesLine(SalesInvoiceHeader."No. Series", SalesInvoiceHeader."Posting Date", true, NoSeriesLine, 1);
                    SSHashDocType := SSCreateSignature.GetInvoiceDocumentTypeBySeriesNo(NoSeriesLine."Series Code");
                    SSHashNoSeries := NoSeriesLine."PTSS SAF-T No. Series";
                    SSHashDocNo := CopyStr(SalesInvoiceHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1, StrLen(SalesInvoiceHeader."No."));
                    SalesInvoiceHeader.CalcFields("Amount Including VAT", "PTSS Withholding Tax Amount");
                    SSHashAmountIncludingVAT := ABS(SalesInvoiceHeader."Amount Including VAT") + ABS(SalesInvoiceHeader."PTSS Withholding Tax Amount");

                    PreviousHashNo := SSCreateSignature.GetHash(SSHashDocType, SalesInvoiceHeader."Posting Date", SSHashDocNo, SSHashNoSeries, SalesInvoiceHeader."Currency Code", SalesInvoiceHeader."Currency Factor", SSHashAmountIncludingVAT, PreviousHashNo, SalesInvoiceHeader."PTSS Creation Date", SalesInvoiceHeader."PTSS Creation Time");

                    Verify.HashNoIsSequential(PreviousHashNo, SalesInvoiceHeader."PTSS Hash");
                UNTIL SalesInvoiceHeader.Next() = 0;
            END;
        end;
        if SalesDocumentType = SalesDocumentType::"Credit Memo" then begin
            NoSeries.Get(SalesRec."Posted Credit Memo Nos.");
            NoSeriesLine.Get(NoSeries.Code, 10000);

            if IsPrepayment then begin
                NoSeries.Reset();
                NoSeriesLine.Reset();
                NoSeries.Get(SalesRec."Posted Prepmt. Cr. Memo Nos.");
                NoSeriesLine.Get(NoSeries.Code, 10000);
            end;

            if IsIntegretion then begin
                NoSeries.Reset();
                NoSeriesLine.Reset();
                NoSeries.Get(SalesRec."PTSS Int. Cr.Memo Series No.");
                NoSeriesLine.Get(NoSeries.Code, 10000);
            end;

            if IsRecovery then begin
                NoSeries.Reset();
                NoSeriesLine.Reset();
                NoSeries.Get(SalesRec."PTSS rec. Cr.Memo Series No.");
                NoSeriesLine.Get(NoSeries.Code, 10000);
            end;

            SalesCrMemoHeader.RESET;
            SalesCrMemoHeader.SetRange(SalesCrMemoHeader."No. Series", NoSeries.code);
            IF SalesCrMemoHeader.FindSet() THEN BEGIN
                REPEAT
                    NoSeriesMgt.GetAndValidateNoSeriesLine(SalesCrMemoHeader."No. Series", SalesCrMemoHeader."Posting Date", true, NoSeriesLine, 1);
                    SSHashDocType := SSCreateSignature.GetInvoiceDocumentTypeBySeriesNo(NoSeriesLine."Series Code");
                    SSHashNoSeries := NoSeriesLine."PTSS SAF-T No. Series";
                    SSHashDocNo := CopyStr(SalesCrMemoHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1, StrLen(SalesCrMemoHeader."No."));
                    SalesCrMemoHeader.CalcFields("Amount Including VAT", "PTSS Withholding Tax Amount");
                    SSHashAmountIncludingVAT := ABS(SalesCrMemoHeader."Amount Including VAT") + ABS(SalesCrMemoHeader."PTSS Withholding Tax Amount");

                    PreviousHashNo := SSCreateSignature.GetHash(SSHashDocType, SalesCrMemoHeader."Posting Date", SSHashDocNo, SSHashNoSeries, SalesCrMemoHeader."Currency Code", SalesCrMemoHeader."Currency Factor", SSHashAmountIncludingVAT, PreviousHashNo, SalesCrMemoHeader."PTSS Creation Date", SalesCrMemoHeader."PTSS Creation Time");

                    Verify.HashNoIsSequential(PreviousHashNo, SalesCrMemoHeader."PTSS Hash");
                UNTIL SalesCrMemoHeader.Next() = 0;
            END;
        end;
    end;

    procedure ValidateHashNoWorkingDocuments(NumberOfOrders: Integer; WDDocumentType: Enum "PTSS SAF-T Working Doc Type Enum")
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        SalesRec: Record "Sales & Receivables Setup";
        ServiceMgtSetup: Record "Service Mgt. Setup";
        WorkingDocumentsHeader: Record "PTSS Working Documents Header";
        PreviousHashNo, LastHashUsed : Text;
        NoSeriesMgt: Codeunit "PTSS No. Series Management";
        SSHashDocType, SSHashNoSeries, SSHashDocNo : Code[100];
        SSHashAmountIncludingVAT: Decimal;
        DateCreated: Date;
        TimeCreated: Time;
    begin
        SalesRec.Get();
        ServiceMgtSetup.Get();

        Case WDDocumentType of
            WDDocumentType::"OR":
                begin
                    if not NoSeries.Get(SalesRec."PTSS WD Sales Quote Nos.") then begin
                        NoSeries.Get(ServiceMgtSetup."PTSS WD Service Quote Nos.")
                    end;
                    NoSeriesLine.Get(NoSeries.Code, 10000);
                end;
            WDDocumentType::NE:
                begin
                    if not NoSeries.Get(SalesRec."PTSS WD Sales Order Nos.") then begin
                        NoSeries.Get(ServiceMgtSetup."PTSS WD Service Order Nos.");
                    end;
                    NoSeriesLine.Get(NoSeries.Code, 10000);
                end;
            WDDocumentType::OU:
                begin
                    NoSeries.Get(SalesRec."PTSS WD Blank. Sales Order Nos");
                    NoSeriesLine.Get(NoSeries.Code, 10000);
                end;
            WDDocumentType::PF:
                begin
                    NoSeries.Get(SalesRec."PTSS WD Proforma Invoice Nos.");
                    NoSeriesLine.Get(NoSeries.Code, 10000);
                end;
        End;

        WorkingDocumentsHeader.SetRange(WorkingDocumentsHeader."No. Series", NoSeries.code);
        IF WorkingDocumentsHeader.FindSet() THEN BEGIN
            REPEAT
                NoSeriesMgt.GetAndValidateNoSeriesLine(WorkingDocumentsHeader."Posting No. Series", WorkingDocumentsHeader."Posting Date", true, NoSeriesLine, 3);
                SSHashDocType := SSCreateSignature.GetWorkingDocumentTypeBySeriesNo(NoSeriesLine."Series Code");
                SSHashNoSeries := NoSeriesLine."PTSS SAF-T No. Series";
                SSHashDocNo := CopyStr(WorkingDocumentsHeader."No.", NoSeriesLine."PTSS SAF-T No. Series Del." + 1, StrLen(WorkingDocumentsHeader."No."));
                WorkingDocumentsHeader.CalcFields("Amount Including VAT", "PTSS Withholding Tax Amount");
                SSHashAmountIncludingVAT := ABS(WorkingDocumentsHeader."Amount Including VAT") + ABS(WorkingDocumentsHeader."PTSS Withholding Tax Amount");

                PreviousHashNo := SSCreateSignature.GetHash(SSHashDocType, WorkingDocumentsHeader."Date Created", SSHashDocNo, SSHashNoSeries, WorkingDocumentsHeader."Currency Code", WorkingDocumentsHeader."Currency Factor", SSHashAmountIncludingVAT, PreviousHashNo, WorkingDocumentsHeader."Date Created", WorkingDocumentsHeader."Time Created");

                Verify.HashNoIsSequential(PreviousHashNo, WorkingDocumentsHeader.Hash);
            UNTIL WorkingDocumentsHeader.Next() = 0;
        END else begin
            error('Working Document Not Found')
        end;
    end;

    procedure ChangeDocType(Var NoSeries: Record "No. Series"; SAFTType: Text)
    var
    begin
        NoSeries.SetRange(Code, NoSeries.Code);
        if NoSeries.FindSet() then begin

            case SAFTType of
                'FT':
                    NoSeries.Validate("PTSS SAF-T Invoice Type", NoSeries."PTSS SAF-T Invoice Type"::FT);
                'RG':
                    NoSeries.validate("PTSS Receipt Type", NoSeries."PTSS Receipt Type"::"PTSS Other Receipts");
                'NC':
                    NoSeries.Validate("PTSS SAF-T Invoice Type", NoSeries."PTSS SAF-T Invoice Type"::NC);
                'ND':
                    NoSeries.Validate("PTSS SAF-T Invoice Type", NoSeries."PTSS SAF-T Invoice Type"::ND);
                'GR':
                    NoSeries.Validate("PTSS GTAT Document Type", NoSeries."PTSS GTAT Document Type"::GR);
            end;
            NoSeries.modify();
        end
    end;

    procedure CalculateTotalsWithoutRoundingSales(SalesHeader: Record "Sales Header"; var ExpectedTotalAmountExclVAT: decimal; var ExpectedTotalAmountInclVAT: Decimal; var ExpectedTotalWithholding: decimal; var ExpectedTotalVATAmount: decimal)
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesInvoiceLine: Record "Sales Invoice Line";
        WithholdingTaxCodes: Record "PTSS Withholding Tax Codes";
    begin
        SalesInvoiceHeader.get(SalesHeader."Last Posting No.");
        SalesInvoiceLine.setrange("Document No.", SalesHeader."Last Posting No.");
        if SalesInvoiceLine.FindSet() then begin
            repeat
                if not SalesInvoiceLine."PTSS Withholding Line" then begin
                    ExpectedTotalAmountExclVAT += (SalesInvoiceLine."Unit Price" * SalesInvoiceLine.Quantity * 0.01 * (100 - SalesInvoiceLine."Line Discount %"));
                    ExpectedTotalVATAmount += (SalesInvoiceLine."Unit Price" * SalesInvoiceLine.Quantity * 0.01 * (100 - SalesInvoiceLine."Line Discount %") * 0.01 * SalesInvoiceLine."VAT %");
                    ExpectedTotalAmountInclVAT += (SalesInvoiceLine."Unit Price" * SalesInvoiceLine.Quantity * 0.01 * (100 - SalesInvoiceLine."Line Discount %")) + (SalesInvoiceLine."Unit Price" * SalesInvoiceLine.Quantity * 0.01 * (100 - SalesInvoiceLine."Line Discount %") * 0.01 * SalesInvoiceLine."VAT %");
                end else begin
                    if SalesInvoiceLine."PTSS Withholding Tax Code 1" <> '' then begin
                        WithholdingTaxCodes.Get(SalesInvoiceLine."PTSS Withholding Tax Code 1");
                        ExpectedTotalWithholding += Abs(SalesInvoiceLine."Unit Price" * SalesInvoiceLine.Quantity * (0.01 * (100 - SalesInvoiceLine."Line Discount %")) * (0.01 * WithholdingTaxCodes.Tax));
                    end;

                    if SalesInvoiceLine."PTSS Withholding Tax Code 2" <> '' then begin
                        WithholdingTaxCodes.Get(SalesInvoiceLine."PTSS Withholding Tax Code 2");
                        ExpectedTotalWithholding += Abs(SalesInvoiceLine."Unit Price" * SalesInvoiceLine.Quantity * (0.01 * (100 - SalesInvoiceLine."Line Discount %")) * (0.01 * WithholdingTaxCodes.Tax));
                    end;
                end;
                WithholdingTaxCodes.Reset();
            until SalesInvoiceLine.Next() = 0;
        end;
    end;

    procedure CalculateTotalsWithoutRoundingPurchase(PurchaseHeader: Record "Purchase Header"; var ExpectedTotalAmountExclVAT: decimal; var ExpectedTotalAmountInclVAT: Decimal; var ExpectedTotalWithholding: decimal; var ExpectedTotalVATAmount: decimal)
    var
        PurchInvoiceHeader: Record "Purch. Inv. Header";
        PurchInvoiceLine: Record "Purch. Inv. Line";
        WithholdingTaxCodes: Record "PTSS Withholding Tax Codes";
    begin
        PurchInvoiceHeader.get(PurchaseHeader."Last Posting No.");
        PurchInvoiceLine.setrange("Document No.", PurchaseHeader."Last Posting No.");
        if PurchInvoiceLine.FindSet() then begin
            repeat
                if not PurchInvoiceLine."PTSS Withholding Line" then begin
                    ExpectedTotalAmountExclVAT += (PurchInvoiceLine."Direct Unit Cost" * PurchInvoiceLine.Quantity * 0.01 * (100 - PurchInvoiceLine."Line Discount %"));
                    ExpectedTotalVATAmount += (PurchInvoiceLine."Direct Unit Cost" * PurchInvoiceLine.Quantity * 0.01 * (100 - PurchInvoiceLine."Line Discount %") * 0.01 * PurchInvoiceLine."VAT %");
                    ExpectedTotalAmountInclVAT += (PurchInvoiceLine."Direct Unit Cost" * PurchInvoiceLine.Quantity * 0.01 * (100 - PurchInvoiceLine."Line Discount %")) + (PurchInvoiceLine."Direct Unit Cost" * PurchInvoiceLine.Quantity * 0.01 * (100 - PurchInvoiceLine."Line Discount %") * 0.01 * PurchInvoiceLine."VAT %");
                end else begin
                    if PurchInvoiceLine."PTSS Withholding Tax Code 1" <> '' then begin
                        WithholdingTaxCodes.Get(PurchInvoiceLine."PTSS Withholding Tax Code 1");
                        ExpectedTotalWithholding += Abs(PurchInvoiceLine."Direct Unit Cost" * PurchInvoiceLine.Quantity * (0.01 * (100 - PurchInvoiceLine."Line Discount %")) * (0.01 * WithholdingTaxCodes.Tax));
                    end;

                    if PurchInvoiceLine."PTSS Withholding Tax Code 2" <> '' then begin
                        WithholdingTaxCodes.Get(PurchInvoiceLine."PTSS Withholding Tax Code 2");
                        ExpectedTotalWithholding += Abs(PurchInvoiceLine."Direct Unit Cost" * PurchInvoiceLine.Quantity * (0.01 * (100 - PurchInvoiceLine."Line Discount %")) * (0.01 * WithholdingTaxCodes.Tax));
                    end;
                end;
                WithholdingTaxCodes.Reset();
            until PurchInvoiceLine.Next() = 0;
        end;
    end;

    procedure AddDiscountAndWithholdingTaxToTheSalesLine(var SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line"; DocumentLine: Integer; Discount: Decimal; HasWithholding: Boolean; Withholding1: Decimal; Withholding2: Decimal)
    var
        WithholdingTaxCodes: Record "PTSS Withholding Tax Codes";
        SalesDocLine: Integer;
    begin
        SalesLine.Get(SalesHeader."Document Type", SalesHeader."No.", DocumentLine);
        SalesLine.validate("Line Discount %", Discount);

        if HasWithholding then begin
            SalesLine.Validate("PTSS Withholding Tax", HasWithholding);
            if not WithholdingTaxCodes.Get(Withholding1) or not WithholdingTaxCodes.Get(Withholding2) then begin
                SSLib.CreateWithholdingCode(WithholdingTaxCodes, true, Withholding1, Withholding2);
            end;

            WithholdingTaxCodes.Reset();
            WithholdingTaxCodes.Findset();
            if Withholding2 <> 0 then begin
                if WithholdingTaxCodes.Code = '' then begin
                    WithholdingTaxCodes.Next();
                    SalesHeader.Validate("PTSS Withholding Tax Code", WithholdingTaxCodes.Code);
                    WithholdingTaxCodes.Next();
                    SalesHeader.Validate("PTSS Withholding Tax Code 2", WithholdingTaxCodes.Code);
                end else begin
                    SalesHeader.Validate("PTSS Withholding Tax Code", WithholdingTaxCodes.Code);
                    WithholdingTaxCodes.Next();
                    SalesHeader.Validate("PTSS Withholding Tax Code 2", WithholdingTaxCodes.Code);
                end;
            end else begin
                if WithholdingTaxCodes.Code = '' then begin
                    WithholdingTaxCodes.Next();
                    SalesHeader.Validate("PTSS Withholding Tax Code", WithholdingTaxCodes.Code);
                end else begin
                    SalesHeader.Validate("PTSS Withholding Tax Code", WithholdingTaxCodes.Code);
                end;
            end;
        end;
        SalesLine.Modify(true);
        SalesHeader.Modify(true);
    end;

    #endregion

    var
        LibRandom: Codeunit "Library - Random";
        LibERM: Codeunit "Library - ERM";
        SSLib: Codeunit "PTSS Library";
        LibInv: Codeunit "Library - Inventory";
        LibSales: Codeunit "Library - Sales";
        LibUti: Codeunit "Library - Utility";
        Verify: Codeunit "PTSS Verify Tests";
        LibPur: Codeunit "Library - Purchase";
        gLibrarySetupStorage: Codeunit "Library - Setup Storage";
        gLibraryVariableStorage: Codeunit "Library - Variable Storage";
        SSCreateSignature: Codeunit "PTSS Create Signature";
    // [EventSubscriber(ObjectType::Codeunit, 44, 'OnSelectReportLayoutCode', '', false, false)]
    // local procedure PTSSOnSelectReportLayoutCode_C44(ObjectId: Integer; var LayoutCode: Text; var LayoutType: Option "None",RDLC,Word,Excel,Custom; var IsHandled: Boolean)
    // begin
    //     IsHandled := true;

    //     LayoutType := LayoutType::RDLC;

    //     ObjectId := 31023117;
    // end;


}