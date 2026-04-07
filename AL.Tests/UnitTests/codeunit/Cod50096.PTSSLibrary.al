codeunit 50096 "PTSS Library"
{
    #region jrosa
    procedure CreatePostCode(var PostCode: Record "Post Code")
    var
        RegionCode: Record "Country/Region";
    begin
        CreateCountryRegion(RegionCode);
        RegionCode.Validate("ISO Code", 'PT');
        //RegionCode.Validate("ISO Code", LibUtil.GenerateRandomAlphabeticText(2,1));
        RegionCode.Modify();
        //if not RegionCode.Get('PT') then begin
        PostCode.Init();
        PostCode.Code := Format(LibUtil.GenerateRandomNumericText(4)) + '-' + Format(LibUtil.GenerateRandomNumericText(3));
        PostCode.City := LibUtil.GenerateRandomcode(PostCode.FieldNo(City), Database::"Post Code");
        PostCode."Country/Region Code" := RegionCode.Code;
        PostCode.Insert();
        //end;
    end;

    procedure CreateCustomerWithVATNo(var Customer: Record Customer)
    var
        Salesperson: Record "Salesperson/Purchaser";
        Contact: Record "Contact";
        ContactNo: Code[20];
    begin
        LibSales.CreateCustomer(Customer);
        TesterHelper.FillCustomerAddressFastTab(Customer);
        Customer."VAT Registration No." := LibERM.GenerateVATRegistrationNo('PT');
        Customer.validate("Gen. Bus. Posting Group", 'NAC');
        Customer.Validate("VAT Bus. Posting Group", 'NACIONAL');
        Customer.validate("Customer Posting Group", 'NAC');
        Customer.validate("Payment Terms Code", '1MES');

        Customer.Modify();
    end;

    procedure CreateItemWithInventory(var Item: Record Item; Qty: Decimal; var Customer: Record Customer; CreateVatSetup: Boolean; ItemPrice: Decimal; VATProdPostOption: Integer)
    var
        ItemJnLine: Record "Item Journal Line";
        Template: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        InvPostSetup: Record "Inventory Posting Setup";
        InvPostGrp: Record "Inventory Posting Group";
        GLAcc: Record "G/L Account";
        VATPostSetup: Record "VAT Posting Setup";
        VATProdPostGrp: Record "VAT Product Posting Group";
        genPostSetup: Record "General Posting Setup";
        GenProdPostGrp: Record "Gen. Product Posting Group";
        GenBusinessPostingGroup: Record "Gen. Business Posting Group";
        VATBusinessPostingGroup: Record "VAT Business Posting Group";
    begin
        LibInv.CreateItem(Item);
        //LibInv.CreateInventoryPostingGroup(InvPostGrp);
        //LibERM.CreateVATProductPostingGroup(VATProdPostGrp);

        case VATProdPostOption of
            1:
                begin
                    VATProdPostGrp.Get('EX_NR');
                end;
            2:
                begin
                    VATProdPostGrp.Get('EX_INT');
                end;
            3:
                begin
                    VATProdPostGrp.Get('EX_RD');
                end;
            4:
                begin
                    VATProdPostGrp.Get('EX_ISE');
                end;
        end;

        Item.Validate("Gen. Prod. Posting Group", 'MERC');
        Item.Validate("Item Category Code", 'MERC');
        Item.Validate("Inventory Posting Group", 'MERC');
        Item.validate("VAT Prod. Posting Group", VATProdPostGrp.code);
        Item.validate("Base Unit of Measure", 'UN');
        //LibERM.CreateVATPostingSetup(VatPostSetup, Customer."VAT Bus. Posting Group", Item."VAT Prod. Posting Group");
        // VatPostSetup."PTSS SAF-T PT VAT Code" := VatPostSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate";
        // Vatpostsetup."PTSS SAF-T PT VAT Type Desc." := Vatpostsetup."PTSS SAF-T PT VAT Type Desc."::"VAT Portugal Mainland";
        if not InvPostSetup.get('', 'MERC') then begin
            LibInv.CreateInventoryPostingSetup(InvPostSetup, '', 'MERC');
            TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            InvPostSetup."Inventory Account" := GLAcc."No.";
            InvPostSetup.Modify();
        end;

        if ItemPrice <> 0 then begin
            Item.Validate("Unit Price", ItemPrice);
        end;
        Item.Modify();

        GenProdPostGrp.get(item."Gen. Prod. Posting Group");
        GenBusinessPostingGroup.Get(Customer."Gen. Bus. Posting Group");

        CreateGeneralPostingSetupLine(genPostSetup, GenBusinessPostingGroup, GenProdPostGrp, VATPostSetup, VATProdPostGrp, VATBusinessPostingGroup, Customer);

        LibInv.CreateItemJournalTemplate(Template);
        LibInv.CreateItemJournalBatch(Batch, Template.Name);
        if Qty > 0 then begin
            LibInv.CreateItemJournalLine(ItemJnLine, Template.Name, Batch.Name, ItemJnLine."Entry Type"::"Positive Adjmt.", Item."No.", Qty);
        end else begin
            LibInv.CreateItemJournalLine(ItemJnLine, Template.Name, Batch.Name, ItemJnLine."Entry Type"::"Negative Adjmt.", Item."No.", Qty);
        end;
        ItemJnLine.Validate("Gen. Bus. Posting Group", genPostSetup."Gen. Bus. Posting Group");
        // ItemJnLine.Validate("Inventory Posting Group", InvPostGrp.Code);
        ItemJnLine.Validate("Inventory Posting Group", 'MERC');
        ItemJnLine.Modify(true);

        LibInv.PostItemJournalLine(ItemJnLine."Journal Template Name", ItemJnLine."Journal Batch Name");
    end;

    procedure FillServiceCreditMemoBillToFields(var ServiceHeader: Record "Service Header"; Customer: Record Customer)
    begin
        ServiceHeader.Validate("Ship-to Name", Customer.Name);
        ServiceHeader.Validate("Ship-to Address", Customer.Address);
        ServiceHeader.Validate("Ship-to City", Customer.City);
        ServiceHeader.Validate("Ship-to Post Code", Customer."Post Code");
        ServiceHeader.Validate("Ship-to Country/Region Code", Customer."Country/Region Code");
        ServiceHeader.Modify;
    end;

    procedure CreateFinanceChargeMemo(var FinChrgMemoHeader: Record "Finance Charge Memo Header"; CustomerNo: Code[20]; GLAccNo: Code[20])
    var
        FinChrgMemoLine: Record "Finance Charge Memo Line";
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
    begin
        SalesReceivablesSetup.Get();
        CreateFinChrgMemoHeader(FinChrgMemoHeader, CustomerNo);
        CreateFinChrgMemoLine(FinChrgMemoLine, FinChrgMemoHeader."No.", 0, GLAccNo);
        GiveFinChrgMemoLinePostingGroups(FinChrgMemoLine, CustomerNo);
        FinChrgMemoHeader.Validate("PTSS Sign on Issuing", true);
        //FinChrgMemoHeader.Validate("PTSS Posting No. Series", SalesReceivablesSetup."PTSS Posted Fin. Chrg. M. Nos.");
        FinChrgMemoHeader.Modify();
    end;

    procedure CreateFinChrgMemoHeader(var FinChrgMemoHeader: Record "Finance Charge Memo Header"; CustomerNo: Code[20])
    var
        FinChrgTerms: Record "Finance Charge Terms";
        LibFinChrgMemo: Codeunit "Library - Finance Charge Memo";
    begin
        LibERM.CreateFinanceChargeMemoHeader(FinChrgMemoHeader, CustomerNo);
        LibFinChrgMemo.CreateFinanceChargeTermAndText(FinChrgTerms);
        FinChrgMemoHeader."Fin. Charge Terms Code" := FinChrgTerms.Code;
        FinChrgMemoHeader."Post Additional Fee" := true;
        FinChrgMemoHeader.Modify();
    end;

    procedure CreateFinChrgMemoLine(var FinChrgMemoLine: Record "Finance Charge Memo Line"; FinChrgMemoHeaderNo: Code[20]; Option: Integer; GLAccNo: Code[20])
    begin
        LibERM.CreateFinanceChargeMemoLine(FinChrgMemoLine, FinChrgMemoHeaderNo, 0);
        FinChrgMemoLine.Type := FinChrgMemoLine.Type::"G/L Account";
        FinChrgMemoLine."No." := GLAccNo;
        FinChrgMemoLine.Amount := 1;
        FinChrgMemoLine.Modify();
    end;

    local procedure GiveFinChrgMemoLinePostingGroups(var FinChrgMemoLine: Record "Finance Charge Memo Line"; CustNo: Code[20])
    var
        GenProdPostGrp: Record "Gen. Product Posting Group";
        VATProdPostGrp: Record "VAT Product Posting Group";
        VATPostingSetup: Record "VAT Posting Setup";
        Customer: Record Customer;
    begin
        CreateGenProdPostingGroup(GenProdPostGrp);
        LibERM.CreateVATProductPostingGroup(VATProdPostGrp);
        FinChrgMemoLine."Gen. Prod. Posting Group" := GenProdPostGrp.Code;
        FinChrgMemoLine."VAT Prod. Posting Group" := VATProdPostGrp.Code;
        FinChrgMemoLine.Modify();
        Customer.Get(CustNo);
        LibERM.CreateVATPostingSetup(VATPostingSetup, Customer."VAT Bus. Posting Group", VATProdPostGrp.Code);
    end;

    procedure CreateReminder(var ReminderHeader: Record "Reminder Header"; CustomerNo: Code[20])
    var
        ReminderLine: Record "Reminder Line";
        ReminderTerms: Record "Reminder Terms";
        CustPostingGrp: Record "Customer Posting Group";
    begin
        LibERM.CreateReminderHeader(ReminderHeader);
        LibERM.CreateReminderLine(ReminderLine, ReminderHeader."No.", Enum::"Reminder Source Type"::"G/L Account");

        ReminderHeader."Customer No." := CustomerNo;
        LibSales.CreateCustomerPostingGroup(CustPostingGrp);
        ReminderHeader."Customer Posting Group" := CustPostingGrp.Code;
        CreateReminderTerms(ReminderTerms);
        ReminderHeader.validate("Reminder Terms Code", ReminderTerms.Code);
        ReminderHeader.Modify();

        ReminderLine.Amount := 1;
        ReminderLine.Modify();
    end;

    procedure PostReminder(var ReminderHeader: Record "Reminder Header")
    var
        ReminderPage: Testpage Reminder;
    begin
        Commit();
        ReminderPage.OpenEdit();
        ReminderPage.GoToRecord(ReminderHeader);
        ReminderPage.Issue.Invoke();
    end;

    procedure CreateLocation(var Location: Record Location)
    var
        PostCode: Record "Post Code";
    begin
        WareHouseLib.CreateLocationWithInventoryPostingSetup(Location);
        CreatePostCode(PostCode);
        Location.Validate("Country/Region Code", PostCode."Country/Region Code");
        Location.Validate(Address, LibUtil.GenerateRandomText(4));
        Location.Validate("Post Code", PostCode.Code);
        Location.Validate(City, LibUtil.GenerateRandomText(4));
        Location.Modify(true);
    end;

    procedure PostSalesDebitMemo(var SalesHeader: Record "Sales Header")
    var
        DebitMemoPage: TestPage "PTSS Sales Debit Memo";
    begin
        SalesHeader."PTSS Debit Memo" := True;
        SalesHeader.Modify();
        DebitMemoPage.OpenEdit();
        DebitMemoPage.GoToRecord(SalesHeader);
        DebitMemoPage.Post.Invoke();
    end;

    procedure PostServiceCreditMemo(var ServiceHeader: Record "Service Header")
    var
        ServiceCreditMemoPage: TestPage "Service Credit Memo";
    begin
        ServiceCreditMemoPage.OpenEdit();
        ServiceCreditMemoPage.GoToRecord(ServiceHeader);
        ServiceCreditMemoPage.Post.Invoke();
    end;

    procedure CreateAuxGLAcc(var GLAcc: Record "G/L Account"; Name: Text)
    begin
        TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
        GLAcc."Account Type" := 0; // Auxiliary
        GLAcc."Direct Posting" := True;
        GLAcc.Modify();
    end;

    procedure CreateVATBusinessPostingGroup(var VATBusinessPostingGroup: Record "VAT Business Posting Group"; CodeT: Code[30])
    begin
        VATBusinessPostingGroup.Init();
        VATBusinessPostingGroup.Validate(Code, CodeT);

        // Validating Code as Name because value is not important.
        VATBusinessPostingGroup.Validate(Description, VATBusinessPostingGroup.Code);
        VATBusinessPostingGroup.Insert(true);
    end;

    procedure CreateGeneralPostingSetupLineVendor(var GenPostSetup: Record "General Posting Setup"; var GenProdPostGrp: Record "Gen. Product Posting Group"; var VATPostingSetup: Record "VAT Posting Setup"; var VATProductPostingGroup: Record "VAT Product Posting Group"; var Vendor: Record Vendor)
    var
        GenBusPostGrp: Record "Gen. Business Posting Group";
        VATBusinessPostingGroup: Record "VAT Business Posting Group";
        GLAcc: Record "G/L Account";
    begin
        if GenBusPostGrp.code = '' then begin
            CreateGenBusPostingGroup(GenBusPostGrp);
        end;
        if GenProdPostGrp.code = '' then begin
            CreateGenProdPostingGroup(GenProdPostGrp);
        end;
        if not GenPostSetup.get(GenBusPostGrp.Code, GenProdPostGrp.Code) then begin
            LibERM.CreateGeneralPostingSetup(GenPostSetup, GenBusPostGrp.Code, GenProdPostGrp.Code);
        end;

        GenPostSetup.validate("Sales Account", TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999999)), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Sales Prepayments Account", TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999999)), Enum::"G/L Account Type"::Posting));
        GenPostSetup.validate("Sales Credit Memo Account", TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999999)), Enum::"G/L Account Type"::Posting));
        GenPostSetup.validate("Purch. Account", TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999999)), Enum::"G/L Account Type"::Posting));
        GenPostSetup.validate("COGS Account", TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999999)), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Purch. Line Disc. Account", TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999999)), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("PTSS Cr.M Dir. Cost Appl. Acc.", TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999999)), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Purch. Credit Memo Account", TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999999)), Enum::"G/L Account Type"::Posting));

        if VATBusinessPostingGroup.code = '' then begin
            LibERM.CreateVATBusinessPostingGroup(VATBusinessPostingGroup);
        end;
        if VATProductPostingGroup.code = '' then begin
            LibERM.CreateVATProductPostingGroup(VATProductPostingGroup);
        end;
        if not VATPostingSetup.get(VATBusinessPostingGroup.code, VATProductPostingGroup.code) then begin
            //LibERM.CreateVATPostingSetup(VATPostingSetup, VATBusinessPostingGroup.code, VATProductPostingGroup.code);
            case VATProductPostingGroup.Code of
                'EX_NR':
                    begin
                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProductPostingGroup, VATBusinessPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate");
                    end;
                'EX_INT':
                    begin
                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProductPostingGroup, VATBusinessPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Intermediate tax rate");
                    end;
                'EX_RD':
                    begin
                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProductPostingGroup, VATBusinessPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Reduced tax rate");
                    end;
                'EX_ISE':
                    begin
                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProductPostingGroup, VATBusinessPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                    end;
            end;
        end;

        Vendor.Validate("Gen. Bus. Posting Group", GenBusPostGrp.Code);
        Vendor.validate("VAT Bus. Posting Group", VATBusinessPostingGroup.code);
        GenPostSetup.modify(true);
        Vendor.Modify();
    end;

    procedure CreateNoSeriesLineWithSAFT(var NoSeries: Record "No. Series"; NoSeriesCode: Code[20]; StartingNo: Code[20]; EndingNo: Code[20]; GTAT: Boolean; GTATType: Option; InvoiceType: Option)
    var
        NoSeriesLine: Record "No. Series Line";
        RecRef: RecordRef;
    begin
        LibUtil.CreateNoSeries(NoSeries, true, true, false);
        NoSeries.Rename(NoSeriesCode);

        if GTAT then
            NoSeries.Validate("PTSS GTAT Document Type", GTATType)
        else
            NoSeries.Validate("PTSS SAF-T Invoice Type", InvoiceType);

        NoSeries.Modify(true);

        // LibUtil.CreateNoSeriesLine(NoSeriesLine, NoSeries.Code, StrSubstNo('%1%2', NoSeriesCode, StartingNo), StrSubstNo('%1%2', NoSeriesCode, EndingNo));
        // NoSeriesLine.Validate("Starting Date", today);
        // NoSeriesLine.Validate("PTSS SAF-T No. Series Del.", StrLen(NoSeriesCode));
        // NoSeriesLine.Modify();

        NoSeriesLine.Init();
        NoSeriesLine.Validate("Series Code", NoSeries.Code);
        RecRef.GetTable(NoSeriesLine);
        NoSeriesLine.Validate("Line No.", libutil.GetNewLineNo(RecRef, NoSeriesLine.FieldNo("Line No.")));

        if StrSubstNo('%1%2', NoSeriesCode, StartingNo) = '' then
            NoSeriesLine.Validate("Starting No.", PadStr(InsStr(NoSeries.Code, '00000000', 3), 10))
        else
            NoSeriesLine.Validate("Starting No.", StrSubstNo('%1%2', NoSeriesCode, StartingNo));

        if StrSubstNo('%1%2', NoSeriesCode, EndingNo) = '' then
            NoSeriesLine.Validate("Ending No.", PadStr(InsStr(NoSeries.Code, '99999999', 3), 10))
        else
            NoSeriesLine.Validate("Ending No.", StrSubstNo('%1%2', NoSeriesCode, EndingNo));

        NoSeriesLine.Validate("Starting Date", today);
        NoSeriesLine.Validate("PTSS SAF-T No. Series Del.", StrLen(NoSeriesCode));
        NoSeriesLine.Validate("PTSS AT Validation Code", 'DP2' + LibUtil.GenerateRandomAlphabeticText(8, 0));

        NoSeriesLine.Insert(true)
    end;

    procedure CreateNoSeriesLineWithSAFTV2(NoSeries: Record "No. Series"; NoSeriesCode: Code[20]; StartingNo: Code[20]; EndingNo: Code[20]; GTAT: Boolean; GTATType: Option; InvoiceType: Option; WDType: Enum "PTSS SAF-T Working Doc Type Enum")
    var
        NoSeriesLine: Record "No. Series Line";
        RecRef: RecordRef;
    begin
        LibUtil.CreateNoSeries(NoSeries, true, true, false);
        NoSeries.Rename(NoSeriesCode);

        if Format(GTATType) <> '' then begin
            NoSeries.Validate("PTSS GTAT Document Type", GTATType)
        end;

        if Format(InvoiceType) <> '' then begin
            NoSeries.Validate("PTSS SAF-T Invoice Type", InvoiceType);
        end;

        if WDType <> WDType::" " then begin
            NoSeries.Validate("PTSS SAF-T Working Doc Type", WDType);
        end;

        NoSeries."Default Nos." := true;

        NoSeries.Modify(true);

        // LibUtil.CreateNoSeriesLine(NoSeriesLine, NoSeries.Code, StrSubstNo('%1%2', NoSeriesCode, StartingNo), StrSubstNo('%1%2', NoSeriesCode, EndingNo));
        // NoSeriesLine.Validate("Starting Date", today);
        // NoSeriesLine.Validate("PTSS SAF-T No. Series Del.", StrLen(NoSeriesCode));
        // NoSeriesLine.Modify();

        NoSeriesLine.Init();
        NoSeriesLine.Validate("Series Code", NoSeries.Code);
        RecRef.GetTable(NoSeriesLine);
        NoSeriesLine.Validate("Line No.", libutil.GetNewLineNo(RecRef, NoSeriesLine.FieldNo("Line No.")));

        if StrSubstNo('%1%2', NoSeriesCode, StartingNo) = '' then
            NoSeriesLine.Validate("Starting No.", PadStr(InsStr(NoSeries.Code, '00000000', 3), 10))
        else
            NoSeriesLine.Validate("Starting No.", StrSubstNo('%1%2', NoSeriesCode, StartingNo));

        if StrSubstNo('%1%2', NoSeriesCode, EndingNo) = '' then
            NoSeriesLine.Validate("Ending No.", PadStr(InsStr(NoSeries.Code, '99999999', 3), 10))
        else
            NoSeriesLine.Validate("Ending No.", StrSubstNo('%1%2', NoSeriesCode, EndingNo));

        NoSeriesLine.Validate("Starting Date", today);
        NoSeriesLine.Validate("PTSS SAF-T No. Series Del.", StrLen(NoSeriesCode));

        NoSeriesLine.Insert(true);

        if (NoSeries."PTSS SAF-T Working Doc Type" <> NoSeries."PTSS SAF-T Working Doc Type"::" ") or (format(NoSeries."PTSS SAF-T Invoice Type") <> '') or (format(NoSeries."PTSS GTAT Document Type") <> '') then begin
            NoSeriesLine.Validate("PTSS AT Validation Code", LibUtil.GenerateRandomAlphabeticText(8, 0));
            noseriesline.modify();
        end;
        NoSeries.Modify();
    end;

    procedure ChangeSalesAndReceivablesSetupSeries(NoSeries: Record "No. Series"; DocType: Text)
    var
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
    begin
        SalesReceivablesSetup.Get();

        case DocType of
            'Invoices':
                SalesReceivablesSetup.Validate("Invoice Nos.", NoSeries.Code);
            'Posted Invoices':
                SalesReceivablesSetup.Validate("Posted Invoice Nos.", NoSeries.Code);
            'Credit Sales Memo':
                SalesReceivablesSetup.Validate("Credit Memo Nos.", NoSeries.Code);
            'Posted Credit Sales Memo':
                SalesReceivablesSetup.Validate("Posted Credit Memo Nos.", NoSeries.Code);
            'Posted Prepmt. Credit Memo':
                SalesReceivablesSetup.Validate("Posted Prepmt. Cr. Memo Nos.", NoSeries.Code);
            'Issued Finance Charge Memo':
                SalesReceivablesSetup.Validate("Issued Fin. Chrg. M. Nos.", NoSeries.Code);
            'Posted Finance Charge Memo':
                SalesReceivablesSetup.Validate("PTSS Posted Fin. Chrg. M. Nos.", NoSeries.Code);
            'Finance Charge Memo':
                SalesReceivablesSetup.Validate("Fin. Chrg. Memo Nos.", NoSeries.Code);
            'Sales Debit Memo':
                SalesReceivablesSetup.Validate("PTSS Debit Memo Nos.", NoSeries.Code);
            'Posted Sales Debit Memo':
                SalesReceivablesSetup.Validate("PTSS Posted Debit Memo Nos.", NoSeries.Code);
            'Posted Prepmt. Invoice':
                SalesReceivablesSetup.Validate("Posted Prepmt. Inv. Nos.", NoSeries.Code);
            'Posted Reminder Nos.':
                SalesReceivablesSetup.Validate("PTSS Posted Reminder Nos.", NoSeries.Code);
            'Reminder':
                SalesReceivablesSetup.Validate("Reminder Nos.", NoSeries.Code);
            'Issued Reminder':
                SalesReceivablesSetup.Validate("Issued Reminder Nos.", NoSeries.Code);
            'Return Order':
                SalesReceivablesSetup.Validate("Return Order Nos.", NoSeries.Code);
            'Posted Return Receipt':
                SalesReceivablesSetup.Validate("Posted Return Receipt Nos.", NoSeries.Code);
            'Posted Shipment':
                SalesReceivablesSetup.Validate("Posted Shipment Nos.", NoSeries.Code);
            'Order':
                SalesReceivablesSetup.Validate("Order Nos.", NoSeries.Code);
            'Receipt':
                SalesReceivablesSetup.Validate("PTSS Receipt Nos.", NoSeries.Code);
            'Cash Receipt':
                SalesReceivablesSetup.validate("PTSS Cash VAT Receipt Nos.", NoSeries.Code);
            'Quote':
                SalesReceivablesSetup.Validate("Quote Nos.", NoSeries.Code);
            'WD-Quote':
                SalesReceivablesSetup.Validate("PTSS WD Sales Quote Nos.", NoSeries.Code);
            'WD-Order':
                SalesReceivablesSetup.Validate("PTSS WD Sales Order Nos.", NoSeries.Code);
            'WD-Pro':
                SalesReceivablesSetup.Validate("PTSS WD Proforma Invoice Nos.", NoSeries.Code);
            'WD-BO':
                SalesReceivablesSetup.Validate("PTSS WD Blank. Sales Order Nos", NoSeries.Code);
        end;

        SalesReceivablesSetup.Modify();
    end;

    procedure CreateSalesDoc(var SalesHeader: Record "Sales Header"; DocType: Enum "Sales Document Type"; Item: Record Item; Qty: Decimal; CustomerNo: Code[20]; var ToGov: Record "G/L Account"; var ToCompany: Record "G/L Account"; var AppliedVAT: Record "G/L Account"; var DeductVAT: Record "G/L Account"; var ReverseCharge: Record "G/L Account"; GenBusPostingGroup: Record "Gen. Business Posting Group"; GenProdPostingGroup: Record "Gen. Product Posting Group"; TaxVAT: Decimal; VAT_D: Decimal; VAT_ND: Decimal; VATCalculationType: Option; SAFTPTVATCode: Option; "PTSS SAF-T PT VAT Type Desc.": Option; ReverseChargeBool: Boolean) SalesLine: Record "Sales Line"
    var
        SalesLine1: Record "Sales Line";
        Region: Record "Country/Region";
        PostCode: Record "Post Code";
        VatPostSetup: Record "VAT Posting Setup";
        VatBusPostGroup: REcord "VAT Business Posting Group";
        VatProdPostGroup: REcord "VAT Product Posting Group";
        VATClause: Record "VAT Clause";
        Contact, contact2 : Record "Contact";
        Customer: record "Customer";
        Salesperson: Record "Salesperson/Purchaser";
    begin
        If not Region.Get('PT') then
            CreatePTCountryRegion(Region);
        CreatePostCode(PostCode);

        LibSales.CreateSalesperson(Salesperson);
        customer.get(CustomerNo);
        customer.Contact := contact."No.";
        customer.modify(false);

        LibSales.CreateSalesHeader(SalesHeader, DocType, CustomerNo);
        SalesHeader.Validate("Due Date", Today);
        SalesHeader.Validate("Sell-to Customer No.", CustomerNo);
        SalesHeader.Validate("Bill-to Customer No.", CustomerNo);
        SalesHeader.Validate("Ship-to Name", LibUtil.GenerateRandomText(30));
        SalesHeader.Validate("Ship-to Address", LibUtil.GenerateRandomText(30));
        SalesHeader.Validate("Ship-to City", LibUtil.GenerateRandomAlphabeticText(6, 0));
        SalesHeader.Validate("Ship-to Post Code", PostCode.Code);
        SalesHeader.Validate("Ship-to Country/Region Code", Region.Code);
        SalesHeader.Validate("Shipment Date", CalcDate('<+1D>', WorkDate()));
        salesheader.validate("Sell-to Contact No.", Contact."No.");
        SalesHeader.Modify();

        VatBusPostGroup.Get(SalesHeader."VAT Bus. Posting Group");
        VatProdPostGroup.Get(Item."VAT Prod. Posting Group");
        if not VatPostSetup.get(VatBusPostGroup.code, VatProdPostGroup.code) then begin
            TesterHelper.CreateGLAccount(ToGov, ToGov."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            TesterHelper.CreateGLAccount(ToCompany, ToCompany."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            TesterHelper.CreateGLAccount(AppliedVAT, AppliedVAT."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            TesterHelper.CreateGLAccount(DeductVAT, DeductVAT."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            TesterHelper.CreateGLAccount(ReverseCharge, ReverseCharge."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            CreateCustomVATPostingSetup(VatBusPostGroup,
                                                VatProdPostGroup,
                                                ToGov,
                                                ToCompany,
                                                AppliedVAT,
                                                DeductVAT,
                                                ReverseCharge,
                                                GenBusPostingGroup,
                                                GenProdPostingGroup,
                                                TaxVAT,
                                                VAT_D,
                                                VAT_ND,
                                                VATCalculationType,
                                                SAFTPTVATCode,
                                                "PTSS SAF-T PT VAT Type Desc.",
                                                'P' + LibUtil.GenerateRandomText(8)
                                                );
        end else begin
            // if VatPostSetup."PTSS Return VAT Acc. (Sales)" = '' then begin
            TesterHelper.CreateGLAccount(ToGov, ToGov."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            TesterHelper.CreateGLAccount(ToCompany, ToCompany."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            TesterHelper.CreateGLAccount(AppliedVAT, AppliedVAT."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            TesterHelper.CreateGLAccount(DeductVAT, DeductVAT."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            TesterHelper.CreateGLAccount(ReverseCharge, ReverseCharge."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            VatPostSetup.Validate("PTSS Return VAT Acc. (Sales)", ToGov."No.");
            VatPostSetup.Validate("PTSS Return VAT Acc. (Purch.)", ToCompany."No.");
            VatPostSetup.Validate("Sales VAT Account", AppliedVAT."No.");
            VatPostSetup.Validate("Purchase VAT Account", DeductVAT."No.");
            VatPostSetup.Validate("Reverse Chrg. VAT Acc.", ReverseCharge."No.");
            // end;

            VatPostSetup.Validate("VAT %", TaxVAT);
            VatPostSetup.Validate("PTSS VAT D. %", VAT_D);
            VatPostSetup.Validate("PTSS VAT N.D. %", VAT_ND);
            //VatPostSetup.Validate("VAT Calculation Type", "VAT Calculation Type");
            VatPostSetup.Validate("PTSS SAF-T PT VAT Code", SAFTPTVATCode);
            VatPostSetup.Validate("PTSS SAF-T PT VAT Type Desc.", "PTSS SAF-T PT VAT Type Desc.");
            VatPostSetup.Modify();
        end;

        if ReverseChargeBool then begin
            VatPostSetup.validate("VAT Calculation Type", VatPostSetup."VAT Calculation Type"::"Reverse Charge VAT");
            VatPostSetup.validate("VAT Clause Code", 'm99');
        end;


        if VATCalculationType = VatPostSetup."VAT Calculation Type"::"PTSS Stamp Duty".ASInteger() then
            VatPostSetup.Validate("VAT Calculation Type", VATCalculationType);
        // VatPostSetup."VAT Calculation Type" := VATCalculationType;
        if SAFTPTVATCode = VatPostSetup."PTSS SAF-T PT VAT Code"::"Stamp Duty" then
            // VatPostSetup."PTSS SAF-T PT VAT Code" := SAFTPTVATCode;
            VatPostSetup.Validate("PTSS SAF-T PT VAT Code", SAFTPTVATCode);
        if ((VatPostSetup."VAT %" = 0) and (VatPostSetup."VAT Clause Code" = '')) or ((VatPostSetup."VAT Calculation Type" = VatPostSetup."VAT Calculation Type"::"Reverse Charge VAT") and (VatPostSetup."VAT Clause Code" = '')) then begin
            Liberm.CreateVATClause(VATClause);
            VatPostSetup.Validate("VAT Clause Code", VATClause.Code);
        end;
        VatPostSetup.Modify(true);

        SalesLine1."VAT Bus. Posting Group" := VatBusPostGroup.Code;
        SalesLine1."VAT Prod. Posting Group" := VatProdPostGroup.Code;

        CreateSalesLineWithShipmentDate(SalesLine, SalesHeader, Enum::"Sales Line Type"::Item, Item, SalesHeader."Shipment Date", Qty, false, Customer, false);

        //LibSales.CreateSalesLine(SalesLine1, SalesHeader, Enum::"Sales Line Type"::Item, Item."No.", Qty);
        SalesLine := SalesLine1;

    end;

    procedure PostSalesDocument(var SalesHeader: Record "Sales Header"; NewShipReceive: Boolean; NewInvoice: Boolean): Code[20]
    begin
        exit(DoPostSalesDoc(SalesHeader, NewShipReceive, NewInvoice, false));
    end;

    local procedure DoPostSalesDoc(var SalesHeader: Record "Sales Header"; NewShipReceive: Boolean; NewInvoice: Boolean; AfterPostSalesDocumentSendAsEmail: Boolean) DocumentNo: Code[20]
    var
        SalesPost: Codeunit "Sales-Post";
        SalesPostPrint: Codeunit "Sales-Post + Print";
        Assert: Codeunit Assert;
        NoSeriesManagement: Codeunit NoSeriesManagement;
        NoSeriesCode: Code[20];
    begin
        SetCorrDocNoSales(SalesHeader);
        with SalesHeader do begin
            Validate(Ship, NewShipReceive);
            Validate(Receive, NewShipReceive);
            Validate(Invoice, NewInvoice);

            case "Document Type" of
                "Document Type"::Invoice:
                    NoSeriesCode := "Posting No. Series";  // posted sales invoice.
                "Document Type"::Order:
                    if NewShipReceive and not NewInvoice then
                        // posted sales shipment.
                        NoSeriesCode := "Shipping No. Series"
                    else
                        NoSeriesCode := "Posting No. Series";  // posted sales invoice.
                "Document Type"::"Credit Memo":
                    NoSeriesCode := "Posting No. Series";  // posted sales credit memo.
                "Document Type"::"Return Order":
                    if NewShipReceive and not NewInvoice then
                        // posted sales return receipt.
                        NoSeriesCode := "Return Receipt No. Series"
                    else
                        NoSeriesCode := "Posting No. Series";  // posted sales credit memo.
                else
                    Assert.Fail(StrSubstNo(WrongDocumentTypeErr, "Document Type"));
            end;
        end;

        if SalesHeader."Posting No." = '' then begin
            //DocumentNo := NoSeriesManagement.GetNextNo(NoSeriesCode, WorkDate(), false);
            DocumentNo := NoSeriesManagement.GetNextNo(NoSeriesCode, Today, true);
            // if salesheader."Document Type" = salesheader."Document Type"::"Credit Memo" then
            SalesHeader."Posting No." := DocumentNo;
        end else begin
            DocumentNo := SalesHeader."Posting No.";
        end;

        Clear(SalesPost);
        if AfterPostSalesDocumentSendAsEmail then begin
            SalesPostPrint.PostAndEmail(SalesHeader)
        end else begin
            SalesPost.Run(SalesHeader);
        end;
    end;

    procedure SetCorrDocNoSales(var SalesHeader: Record "Sales Header")
    begin
        with SalesHeader do
            if "Document Type" in ["Document Type"::"Credit Memo", "Document Type"::"Return Order"] then;
    end;

    procedure ChangeServiceMgtSetupNoSeries(NoSeries: Code[20]; DocType: Text)
    var
        ServiceMgtSetup: Record "Service Mgt. Setup";
    begin
        if ServiceMgtSetup.Get then begin
            case DocType of
                'Service Invoice':
                    ServiceMgtSetup.Validate("Service Invoice Nos.", NoSeries);
                'Service Credit Memo':
                    ServiceMgtSetup.Validate("Service Credit Memo Nos.", NoSeries);
                'Posted Service Shipment':
                    ServiceMgtSetup.Validate("Posted Service Shipment Nos.", NoSeries);
                'Posted Service Invoice':
                    ServiceMgtSetup.Validate("Posted Service Invoice Nos.", NoSeries);
                'Posted Service Credit Memo':
                    ServiceMgtSetup.Validate("Posted Serv. Credit Memo Nos.", NoSeries);
            end;

            ServiceMgtSetup.Modify();
        end;
    end;

    procedure CreateServiceDoc(var ServiceHeader: Record "Service Header";
                                DocType: Enum "Service Document Type";
                                var Customer: Record Customer;
                                var Item: Record Item;
                                Qty: Integer;
                                Amount: Integer;
                                UnitCost: Decimal;
                                UnitPrice: Decimal;
                                ToGov: Record "G/L Account";
                                ToCompany: Record "G/L Account";
                                AppliedVAT: Record "G/L Account";
                                DeductVAT: Record "G/L Account";
                                ReverseCharge: Record "G/L Account";
                                GenBusPostingGroup: Record "Gen. Business Posting Group";
                                GenProdPostingGroup: Record "Gen. Product Posting Group";
                                TaxVAT: Decimal;
                                VAT_D: Decimal; VAT_ND: Decimal;
                                "VAT Calculation Type": Option;
                                "PTSS SAF-T PT VAT Code": Option; "PTSS SAF-T PT VAT Type Desc.": Option)
    var
        ServiceLine: Record "Service Line";
        VatPostSetup: Record "VAT Posting Setup";
        VatBusPostGroup: REcord "VAT Business Posting Group";
        VatProdPostGroup: REcord "VAT Product Posting Group";
        VAtClause: Record "VAT Clause";
    begin
        //LibUtil.GenerateRandomText(7)
        ServLib.CreateServiceHeader(ServiceHeader, DocType, Customer."No.");


        VatBusPostGroup.Get(ServiceHeader."VAT Bus. Posting Group");
        VatProdPostGroup.Get(Item."VAT Prod. Posting Group");

        if not VatPostSetup.get(VatBusPostGroup.code, VatProdPostGroup.code) then begin
            TesterHelper.CreateGLAccount(ToGov, ToGov."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            TesterHelper.CreateGLAccount(ToCompany, ToCompany."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            TesterHelper.CreateGLAccount(AppliedVAT, AppliedVAT."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            TesterHelper.CreateGLAccount(DeductVAT, DeductVAT."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            TesterHelper.CreateGLAccount(ReverseCharge, ReverseCharge."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            CreateCustomVATPostingSetup(VatBusPostGroup,
                                                VatProdPostGroup,
                                                ToGov,
                                                ToCompany,
                                                AppliedVAT,
                                                DeductVAT,
                                                ReverseCharge,
                                                GenBusPostingGroup,
                                                GenProdPostingGroup,
                                                TaxVAT,
                                                VAT_D,
                                                VAT_ND,
                                                "VAT Calculation Type",
                                                "PTSS SAF-T PT VAT Code",
                                                "PTSS SAF-T PT VAT Type Desc.",
                                                LibUtil.GenerateRandomText(8)
                                                );
        end;

        VatPostSetup.get(VatBusPostGroup.code, VatProdPostGroup.code);
        VatPostSetup.Validate("PTSS SAF-T PT VAT Code", "PTSS SAF-T PT VAT Code");
        VatPostSetup.Validate("PTSS SAF-T PT VAT Type Desc.", "PTSS SAF-T PT VAT Type Desc.");
        if (VatPostSetup."VAT Calculation Type" = VatPostSetup."VAT Calculation Type"::"PTSS Stamp Duty") or (VatPostSetup."VAT %" = 0) then begin
            if not VAtClause.FindFirst() then
                CreateVATClause(VAtClause, LibUtil.GenerateRandomText(10));
            VatPostSetup.Validate("VAT Clause Code", VAtClause.Code);
        end;
        TesterHelper.CreateGLAccount(ToGov, ToGov."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
        vatpostsetup.Validate("PTSS Return VAT Acc. (Sales)", ToGov."No.");
        VatPostSetup.Modify();

        ServLib.CreateServiceLineWithQuantity(ServiceLine, ServiceHeader, ServiceLine.Type::Item, Item."No.", Qty);

        ServiceLine."VAT Bus. Posting Group" := VatBusPostGroup.Code;
        ServiceLine."VAT Prod. Posting Group" := VatProdPostGroup.Code;

        ServiceHeader.Validate("Ship-to Name", Customer.Name);
        ServiceHeader.Validate("Ship-to Address", Customer.Address);
        ServiceHeader.Validate("Ship-to City", Customer.city);
        ServiceHeader.Validate("Ship-to Post Code", Customer."Post Code");
        ServiceHeader.Validate("Ship-to Country/Region Code", Customer."Country/Region Code");

        ServiceLine.Validate(Amount, Amount);
        ServiceLine.Validate("Qty. to Invoice", Qty);
        ServiceLine.Validate("Unit Cost", UnitCost);
        ServiceLine.Validate("Unit Price", UnitPrice);
        ServiceLine.Validate("Line Amount", Qty);
        ServiceLine.Validate(Quantity, Qty);
        ServiceLine.Modify();
        ServiceHeader.modify();
    end;

    procedure CreateItemWithInventoryForLocation(var Item: Record Item; Qty: Decimal; Location: Record Location)
    var
        ItemJnLine: Record "Item Journal Line";
        Template: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        GenPostSetup: Record "General Posting Setup";
        GenBusPostGrp: Record "Gen. Business Posting Group";
        GenProdPostGrp: Record "Gen. Product Posting Group";
        InvPostingSetup: Record "Inventory Posting Setup";
        InvPostingGrp: Record "Inventory Posting Group";
        GLAcc: Record "G/L Account";
    begin
        LibInv.CreateItem(Item);

        Item.validate("Unit Price", Random(9999));
        Item.Modify();

        CreateGenBusPostingGroup(GenBusPostGrp);
        CreateGenProdPostingGroup(GenProdPostGrp);
        LibERM.CreateGeneralPostingSetup(GenPostSetup, GenBusPostGrp.Code, GenProdPostGrp.Code);
        GenPostSetup."Inventory Adjmt. Account" := TesterHelper.CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
        GenPostSetup.Modify();

        LibInv.CreateInventoryPostingGroup(InvPostingGrp);
        LibInv.CreateInventoryPostingSetup(InvPostingSetup, Location.Code, InvPostingGrp.Code);
        CreateAuxGLAcc(GLAcc, Format(LibRandom.RandIntInRange(1000, 4999)));
        InvPostingSetup."Inventory Account" := GLAcc."No.";
        InvPostingSetup.Modify();

        LibInv.CreateItemJournalTemplate(Template);
        LibInv.CreateItemJournalBatch(Batch, Template.Name);
        LibInv.CreateItemJournalLine(ItemJnLine, Template.Name, Batch.Name, ItemJnLine."Entry Type"::"Positive Adjmt.", Item."No.", Qty);

        ItemJnLine."Location Code" := Location.Code;
        ItemJnLine."Gen. Bus. Posting Group" := GenBusPostGrp.Code;
        ItemJnLine."Gen. Prod. Posting Group" := GenProdPostGrp.Code;
        ItemJnLine."Inventory Posting Group" := InvPostingGrp.Code;
        ItemJnLine.Modify();

        LibInv.PostItemJournalLine(ItemJnLine."Journal Template Name", ItemJnLine."Journal Batch Name");
    end;

    procedure CreateTransferOrder(var TransferHeader: Record "Transfer Header"; var LocationFrom: Record Location; var LocationTo: Record Location; var Item: Record Item)
    var
        InTransLoc: Record Location;
        TransferLine: Record "Transfer Line";
        GenProdPostGrp: Record "Gen. Product Posting Group";
        GenPostingSetup: Record "General Posting Setup";
        GLAcc: Record "G/L Account";
        InvPostSetup, InvPostSetup2, InvPostSetup3 : Record "Inventory Posting Setup";
        ShipDate: Date;
    begin
        CreateGenProdPostingGroup(GenProdPostGrp);
        LibERM.CreateGeneralPostingSetup(GenPostingSetup, '', GenProdPostGrp.Code);
        GenPostingSetup."Inventory Adjmt. Account" := TesterHelper.CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
        GenPostingSetup.Modify();

        WareHouseLib.CreateInTransitLocation(InTransLoc);
        WareHouseLib.CreateTransferHeader(TransferHeader, LocationFrom.Code, LocationTo.Code, InTransLoc.Code);
        TransferHeader."PTSS Transfer-to VAT Reg. No." := Format(LibRandom.RandIntInRange(100000000, 999999999));
        TransferHeader.Validate("Shipment Date", Calcdate('<+1D>', WorkDate()));
        TransferHeader.Modify();
        WareHouseLib.CreateTransferLine(TransferHeader, TransferLine, Item."No.", 10);

        TransferLine."Gen. Prod. Posting Group" := GenProdPostGrp.Code;
        TransferLine."Inventory Posting Group" := TesterHelper.GiveLocationInvPostingSetupLine(InTransLoc);
        TransferLine.Modify;

        LibInv.CreateInventoryPostingSetup(InvPostSetup2, LocationFrom.Code, TransferLine."Inventory Posting Group");
        LibInv.CreateInventoryPostingSetup(InvPostSetup3, LocationTo.Code, TransferLine."Inventory Posting Group");
        InvPostSetup2."Inventory Account" := GLAcc."No.";
        InvPostSetup3."Inventory Account" := GLAcc."No.";
        InvPostSetup2.Modify();
        InvPostSetup3.Modify();
    end;

    procedure CreateVendorWithVATNo(var Vendor: Record Vendor)
    var
        VATBusPostGrp: Record "VAT Business Posting Group";
        GenBusPostingGrp: Record "Gen. Business Posting Group";
    begin
        LibPurch.CreateVendor(Vendor);
        TesterHelper.FillVendorAddressFastTab(Vendor);
        Vendor."VAT Registration No." := LibERM.GenerateVATRegistrationNo('PT');
        LibERM.CreateVATBusinessPostingGroup(VATBusPostGrp);
        CreateGenBusPostingGroup(GenBusPostingGrp);
        Vendor.Validate("Gen. Bus. Posting Group", GenBusPostingGrp.Code);
        Vendor.Validate("VAT Bus. Posting Group", VATBusPostGrp.code);
        Vendor.Modify();
    end;

    procedure CreateItemWithInventory(var Item: Record Item; Qty: Decimal; var Vendor: Record Vendor; CreateVatSetup: Boolean; ItemPrice: Decimal)
    var
        ItemJnLine: Record "Item Journal Line";
        Template: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        GenBusCode: Code[20];
        Location: Record Location;
        VATProdPostGrp: Record "VAT Product Posting Group";
    begin
        LibInv.CreateItem(Item);

        LibERM.CreateVATProductPostingGroup(VATProdPostGrp);
        Item.Validate("VAT Prod. Posting Group", VATProdPostGrp.Code);
        Item.Modify();

        if ItemPrice <> 0 then begin
            Item.Validate("Unit Cost", ItemPrice);
            Item.Modify();
        end;

        GenBusCode := TesterHelper.FillPostingGroupsVendor(Item, Vendor, CreateVatSetup);

        LibInv.CreateItemJournalTemplate(Template);
        LibInv.CreateItemJournalBatch(Batch, Template.Name);
        LibInv.CreateItemJournalLine(ItemJnLine, Template.Name, Batch.Name, ItemJnLine."Entry Type"::"Positive Adjmt.", Item."No.", Qty);
        ItemJnLine."Gen. Bus. Posting Group" := GenBusCode;
        ItemJnLine."Inventory Posting Group" := TesterHelper.GiveLocationInvPostingSetupLine(Location);
        ItemJnLine.Modify();

        LibInv.PostItemJournalLine(ItemJnLine."Journal Template Name", ItemJnLine."Journal Batch Name");
    end;

    procedure CreatePurchDoc(var PurchHeader: Record "Purchase Header"; PurchDocType: Enum "Purchase Document Type"; var Item: Record Item; Qty: Decimal; var Vendor: Record Vendor; var ToGov: Record "G/L Account"; var ToCompany: Record "G/L Account"; var AppliedVAT: Record "G/L Account"; var DeductVAT: Record "G/L Account"; var ReverseCharge: Record "G/L Account"; GenBusPostingGroup: Record "Gen. Business Posting Group"; GenProdPostingGroup: Record "Gen. Product Posting Group"; TaxVAT: Decimal; VAT_D: Decimal; VAT_ND: Decimal; VATCalculationType: Option; SAFTPTVATCode: Option; SAFTPTVATTypeDesc: Option)
    var
        PurchLine: Record "Purchase Line";
        GenBusPostGrp: Record "Gen. Business Posting Group";
        InvPostingSetup: Record "Inventory Posting Setup";
        InvPostingGrp: Record "Inventory Posting Group";
        GLAcc: Record "G/L Account";
        PurchSetup: Record "Purchases & Payables Setup";
        VatPostSetup: Record "VAT Posting Setup";
        VatBusPostGroup: REcord "VAT Business Posting Group";
        VatProdPostGroup: REcord "VAT Product Posting Group";
        VATClause: Record "VAT Clause";
    begin
        LibInv.CreateInventoryPostingGroup(InvPostingGrp);
        LibInv.CreateInventoryPostingSetup(InvPostingSetup, '', InvPostingGrp.Code);
        InvPostingSetup."Inventory Account" := TesterHelper.CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
        InvPostingSetup.Modify();

        GiveAddressToVendor(Vendor);

        LibPurch.CreatePurchHeader(PurchHeader, PurchDocType, Vendor."No.");

        // PurchSetup.get;
        // PurchHeader."Posting No. Series" := PurchSetup."Posted Return Shpt. Nos.";
        // PurchHeader.Modify;

        VatBusPostGroup.Get(PurchHeader."VAT Bus. Posting Group");
        VatProdPostGroup.Get(Item."VAT Prod. Posting Group");
        if not VatPostSetup.get(VatBusPostGroup.code, VatProdPostGroup.code) then begin
            TesterHelper.CreateGLAccount(ToGov, ToGov."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            TesterHelper.CreateGLAccount(ToCompany, ToCompany."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            TesterHelper.CreateGLAccount(AppliedVAT, AppliedVAT."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            TesterHelper.CreateGLAccount(DeductVAT, DeductVAT."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            TesterHelper.CreateGLAccount(ReverseCharge, ReverseCharge."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);

            CreateCustomVATPostingSetup(VatBusPostGroup,
                                                VatProdPostGroup,
                                                ToGov,
                                                ToCompany,
                                                AppliedVAT,
                                                DeductVAT,
                                                ReverseCharge,
                                                GenBusPostingGroup,
                                                GenProdPostingGroup,
                                                TaxVAT,
                                                VAT_D,
                                                VAT_ND,
                                                VATCalculationType,
                                                SAFTPTVATCode,
                                                SAFTPTVATTypeDesc,
                                                'P' + LibUtil.GenerateRandomText(8)
                                                );
        end else begin
            if VatPostSetup."PTSS Return VAT Acc. (Purch.)" = '' then begin
                TesterHelper.CreateGLAccount(ToGov, ToGov."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
                TesterHelper.CreateGLAccount(ToCompany, ToCompany."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
                TesterHelper.CreateGLAccount(AppliedVAT, AppliedVAT."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
                TesterHelper.CreateGLAccount(DeductVAT, DeductVAT."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
                TesterHelper.CreateGLAccount(ReverseCharge, ReverseCharge."Income/Balance"::"Income Statement", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
                VatPostSetup.Validate("PTSS Return VAT Acc. (Sales)", ToGov."No.");
                VatPostSetup.Validate("PTSS Return VAT Acc. (Purch.)", ToCompany."No.");
                VatPostSetup.Validate("Sales VAT Account", AppliedVAT."No.");
                VatPostSetup.Validate("Purchase VAT Account", DeductVAT."No.");
                VatPostSetup.Validate("Reverse Chrg. VAT Acc.", ReverseCharge."No.");
            end;

            VatPostSetup.Validate("VAT %", TaxVAT);
            VatPostSetup.Validate("PTSS VAT D. %", VAT_D);
            VatPostSetup.Validate("PTSS VAT N.D. %", VAT_ND);
            //VatPostSetup.Validate("VAT Calculation Type", "VAT Calculation Type");
            VatPostSetup.Validate("PTSS SAF-T PT VAT Code", SAFTPTVATCode);
            VatPostSetup.Validate("PTSS SAF-T PT VAT Type Desc.", SAFTPTVATTypeDesc);
            VatPostSetup.Modify();
        end;

        if VATCalculationType = VatPostSetup."VAT Calculation Type"::"PTSS Stamp Duty".AsInteger() then
            VatPostSetup."VAT Calculation Type" := VATCalculationType;
        if SAFTPTVATCode = VatPostSetup."PTSS SAF-T PT VAT Code"::"Stamp Duty" then
            VatPostSetup."PTSS SAF-T PT VAT Code" := SAFTPTVATCode;

        if ((VatPostSetup."VAT %" = 0) and (VatPostSetup."VAT Clause Code" = '')) or ((VatPostSetup."VAT Calculation Type" = VatPostSetup."VAT Calculation Type"::"Reverse Charge VAT") and (VatPostSetup."VAT Clause Code" = '')) then begin
            Liberm.CreateVATClause(VATClause);
            VatPostSetup.Validate("VAT Clause Code", VATClause.Code);
        end;
        VatPostSetup.Modify();

        LibPurch.CreatePurchaseLine(PurchLine, PurchHeader, Enum::"Purchase Line Type"::Item, Item."No.", Qty);
        PurchLine."VAT Bus. Posting Group" := VatBusPostGroup.Code;
        PurchLine."VAT Prod. Posting Group" := VatProdPostGroup.Code;

        FillPurchLine(PurchLine, Item."No.", Vendor."No.", Qty);
        PurchLine.Description := LibUtil.GenerateRandomText(9);
        PurchLine."Posting Group" := InvPostingGrp.Code;
        PurchLine.Modify();

        EnableShipPurchHeader(PurchHeader);
    end;

    procedure FillPurchLine(var PurchLine: Record "Purchase Line"; ItemNo: Code[20]; VendorNo: Code[20]; Qty: Decimal)
    var
        GenBusPostingGrp: Record "Gen. Business Posting Group";
        GenProdPostingGrp: Record "Gen. Product Posting Group";
        Item: Record Item;
        Vendor: Record Vendor;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        VatPostSetup: Record "VAT Posting Setup";
        VatBusPostSetup: Record "VAT Business Posting Group";
        VatProdPostSetup: REcord "VAT Product Posting Group";
    begin
        LibInv.CreateItemUnitOfMeasureCode(ItemUnitOfMeasure, ItemNo, 1);

        CreateGenPostSetupAndFillAccounts(GenBusPostingGrp, GenProdPostingGrp);
        Item.Get(ItemNo);
        Vendor.Get(VendorNo);
        PurchLine.Validate(Type, PurchLine.Type::Item);
        PurchLine.Validate("No.", ItemNo);
        // PurchLine.Validate(Amount, 1);
        PurchLine.Validate("Pay-to Vendor No.", VendorNo);
        PurchLine.Validate(Quantity, Qty);
        PurchLine.Validate("Unit of Measure Code", ItemUnitOfMeasure.Code);
        PurchLine."Gen. Bus. Posting Group" := GenBusPostingGrp.Code;
        PurchLine."Gen. Prod. Posting Group" := GenProdPostingGrp.Code;

        // VatBusPostSetup.Get(Vendor."VAT Bus. Posting Group");
        // VatProdPostSetup.Get(Item."VAT Prod. Posting Group");
        // CreateVATPostingSetupLine(VatPostSetup, VatProdPostSetup, VatBusPostSetup);
        // PurchLine."VAT Bus. Posting Group" := Vendor."VAT Bus. Posting Group";
        // PurchLine."VAT Prod. Posting Group" := Item."VAT Prod. Posting Group";
        PurchLine.Modify(true);
    end;

    procedure PostPurchaseDocument(var PurchaseHeader: Record "Purchase Header"; ToShipReceive: Boolean; ToInvoice: Boolean) DocumentNo: Code[20]
    var
        NoSeriesManagement: Codeunit NoSeriesManagement;
        NoSeriesCode: Code[20];

        PurchaseLine: Record "Purchase Line";
    begin
        // Post the purchase document.
        // Depending on the document type and posting type return the number of the:
        // - purchase receipt,
        // - posted purchase invoice,
        // - purchase return shipment, or
        // - posted credit memo
        SetCorrDocNoPurchase(PurchaseHeader);
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

        PurchaseLine.GET(PurchaseHeader."Document Type", PurchaseHeader."No.", 10000);

        if NoSeriesCode = '' then
            DocumentNo := PurchaseHeader."No."
        else
            DocumentNo :=
            // NoSeriesManagement.GetNextNo(NoSeriesCode, Workdate(), false);
            NoSeriesManagement.GetNextNo(NoSeriesCode, PurchaseHeader."Posting Date", false);
        CODEUNIT.Run(CODEUNIT::"Purch.-Post", PurchaseHeader);
    end;

    procedure SetCorrDocNoPurchase(var PurchHeader: Record "Purchase Header")
    begin
        with PurchHeader do
            if "Document Type" in ["Document Type"::"Credit Memo", "Document Type"::"Return Order"] then;
    end;

    local procedure CreateGenPostSetupAndFillAccounts(var GenBusPostingGrp: Record "Gen. Business Posting Group"; var GenProdPostingGrp: Record "Gen. Product Posting Group")
    var
        GenPostingSetup: Record "General Posting Setup";
        vatPostSetup: Record "VAT Posting Setup";
    begin
        if GenBusPostingGrp.Code = '' then begin
            CreateGenBusPostingGroup(GenBusPostingGrp);
        end;
        if GenProdPostingGrp.Code = '' then begin
            CreateGenProdPostingGroup(GenProdPostingGrp);
        end;
        LibERM.CreateGeneralPostingSetup(GenPostingSetup, GenBusPostingGrp.code, GenProdPostingGrp.code);
        TesterHelper.FillGenPostSetupAccounts(GenPostingSetup);
    end;

    local procedure EnableShipPurchHeader(var PurchHeader: Record "Purchase Header")
    begin
        PurchHeader.Ship := true;
        PurchHeader.Modify();
    end;

    local procedure GiveAddressToVendor(var Vendor: Record Vendor)
    var
        CountryRegion: Record "Country/Region";
    begin
        LibERM.CreateCountryRegion(CountryRegion);
        Vendor."Country/Region Code" := CountryRegion.Code;
        Vendor.Address := LibUtil.GenerateRandomText(4);
        Vendor."Post Code" := LibUtil.GenerateRandomText(4);
        Vendor.City := LibUtil.GenerateRandomText(4);
        Vendor.Modify();
    end;

    procedure CreatePTCountryRegion(var Country: Record "Country/Region")
    begin
        if Country.Get('PT') then
            exit;
        Country.Init();
        Country.Validate(Code, 'PT');
        Country.Insert(true);
    end;

    local procedure CreatePTPostCode(var PostCode: Record "Post Code"; Region: Record "Country/Region")
    begin
        //PostCode.Init();
        PostCode.Validate(Code, CopyStr(LibUtil.GenerateRandomCode(1, 225), 1, LibUtil.GetFieldLength(225, 1)));
        //PostCode.Validate(Code,CopyStr(LibUtil.GenerateRandomCode(PostCode.FieldNo(Code), DATABASE::"Post Code"), 1, LibUtil.GetFieldLength(DATABASE::"Post Code", PostCode.FieldNo(Code))));
        PostCode.Validate(City, CopyStr(LibUtil.GenerateRandomCode(PostCode.FieldNo(City), DATABASE::"Post Code"), 1, LibUtil.GetFieldLength(DATABASE::"Post Code", PostCode.FieldNo(City))));
        PostCode.Validate("Country/Region Code", Region.Code);
        PostCode.Insert(true);
    end;

    procedure CreateVATPostingSetupLine(var VATPostSetup: Record "VAT Posting Setup"; var VATProdPostGrp: Record "VAT Product Posting Group"; var Vendor: Record Vendor)
    var
        VATBusPostGrp: Record "VAT Business Posting Group";
    begin
        if Vendor."VAT Bus. Posting Group" = '' then begin
            LibERM.CreateVATBusinessPostingGroup(VATBusPostGrp);
            Vendor."VAT Bus. Posting Group" := VATBusPostGrp.Code;
            VATBusPostGrp.Modify();
            Vendor.Modify();
        end else begin
            VATBusPostGrp.Get(Vendor."VAT Bus. Posting Group");
        end;
        if VATProdPostGrp.Code = '' then begin
            LibERM.CreateVATProductPostingGroup(VATProdPostGrp);
            VATProdPostGrp.Modify(true);
        end;
        if not VATPostSetup.get(VATBusPostGrp.Code, VATProdPostGrp.Code) then begin
            LibERM.CreateVATPostingSetup(VATPostSetup, VATBusPostGrp.Code, VATProdPostGrp.Code);
        end;
    end;

    procedure PostServiceInvoice(var ServiceHeader: Record "Service Header")
    var
        ServiceInvPage: TestPage "Service Invoice";
    begin
        ServiceInvPage.OpenEdit();
        ServiceInvPage.GoToRecord(ServiceHeader);
        ServiceInvPage.Post.Invoke();
    end;

    procedure CreateSalesDocSimple(var SalesHeader: Record "Sales Header"; DocType: Enum "Sales Document Type"; CustomerNo: Code[20])
    begin
        LibSales.CreateSalesHeader(SalesHeader, DocType, CustomerNo);
        SalesHeader.Validate("Due Date", Today);
        SalesHeader.Validate("Sell-to Customer No.", CustomerNo);
        SalesHeader.Validate("Bill-to Customer No.", CustomerNo);
        SalesHeader.Modify();
    end;

    procedure CreateFairCompensationSetupLine(var FairCompSetup: Record "PTSS Fair Compensation Setup")
    begin
        FairCompSetup.Init();
        FairCompSetup."PTSS Product ID" := LibUtil.GenerateRandomText(4);
        FairCompSetup."PTSS Article" := LibUtil.GenerateRandomText(4);
        FairCompSetup."PTSS Article Description" := LibUtil.GenerateRandomText(4);
        FairCompSetup."PTSS Limit Amount" := 10;
        FairCompSetup."PTSS Calculation Type" := FairCompSetup."PTSS Calculation Type"::Unit;
        FairCompSetup."PTSS Unit Amount" := 10;
        FairCompSetup.Insert();
    end;

    procedure CreateItemWithInventoryFromDifLocation(var Item: Record Item; Qty: Decimal; var Customer: Record Customer)
    var
        ItemJnLine: Record "Item Journal Line";
        Template: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        GenBusCode: Code[20];
        InvPostSetup: Record "Inventory Posting Setup";
        InvPostGrp: Record "Inventory Posting Group";
        GLAcc: Record "G/L Account";
        CountryRegion: Record "Country/Region";
    begin
        LibInv.CreateInventoryPostingGroup(InvPostGrp);
        LibInv.CreateInventoryPostingSetup(InvPostSetup, '', InvPostGrp.Code);
        CreateAuxGLAcc(GLAcc, Format(LibRandom.RandIntInRange(1000, 4999)));
        InvPostSetup."Inventory Account" := GLAcc."No.";
        InvPostSetup.Modify();

        LibInv.CreateItem(Item);
        GenBusCode := TesterHelper.FillPostingGroups(Item, Customer, true);

        LibInv.CreateItemJournalTemplate(Template);
        LibInv.CreateItemJournalBatch(Batch, Template.Name);
        LibInv.CreateItemJournalLine(ItemJnLine, Template.Name, Batch.Name, ItemJnLine."Entry Type"::"Positive Adjmt.", Item."No.", Qty);
        ItemJnLine."Gen. Bus. Posting Group" := GenBusCode;
        ItemJnLine."Inventory Posting Group" := InvPostGrp.Code;
        LibERM.CreateCountryRegion(CountryRegion);
        ItemJnLine."Country/Region Code" := CountryRegion.Code;
        ItemJnLine.Modify();

        LibInv.PostItemJournalLine(ItemJnLine."Journal Template Name", ItemJnLine."Journal Batch Name");
    end;

    procedure CreateItemWithInventoryFromDifLocationWithSerialNos(var Item: Record Item; Qty: Decimal; var Customer: Record Customer)
    var
        ItemJnLine: Record "Item Journal Line";
        Template: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        GenBusCode: Code[20];
        InvPostSetup: Record "Inventory Posting Setup";
        InvPostGrp: Record "Inventory Posting Group";
        GLAcc: Record "G/L Account";
        CountryRegion: Record "Country/Region";
        i: Integer;
        SerialName: Text;
        LibTrack: Codeunit "Library - Item Tracking";
        SerialNoInformation: Record "Serial No. Information";
        ReservEntry: Record "Reservation Entry";
    begin
        LibInv.CreateInventoryPostingGroup(InvPostGrp);
        LibInv.CreateInventoryPostingSetup(InvPostSetup, '', InvPostGrp.Code);
        CreateAuxGLAcc(GLAcc, Format(LibRandom.RandIntInRange(1000, 4999)));
        InvPostSetup."Inventory Account" := GLAcc."No.";
        InvPostSetup.Modify();

        LibInv.CreateItem(Item);
        GenBusCode := TesterHelper.FillPostingGroups(Item, Customer, true);

        LibInv.CreateItemJournalTemplate(Template);
        LibInv.CreateItemJournalBatch(Batch, Template.Name);
        LibInv.CreateItemJournalLine(ItemJnLine, Template.Name, Batch.Name, ItemJnLine."Entry Type"::"Positive Adjmt.", Item."No.", Qty);
        ItemJnLine."Gen. Bus. Posting Group" := GenBusCode;
        ItemJnLine."Inventory Posting Group" := InvPostGrp.Code;
        LibERM.CreateCountryRegion(CountryRegion);
        ItemJnLine."Country/Region Code" := CountryRegion.Code;
        ItemJnLine.Modify();

        i := 0;
        SerialName := 'SERIAL';
        repeat
            LibTrack.CreateSerialNoInformation(SerialNoInformation, Item."No.", '', SerialName + format(i));
            LibTrack.CreateItemJournalLineItemTracking(ReservEntry, ItemJnLine, SerialNoInformation."Serial No.", '', 1);
            i += 1;
        until i = qty;

        LibInv.PostItemJournalLine(ItemJnLine."Journal Template Name", ItemJnLine."Journal Batch Name");
    end;

    procedure CreateSalesDocWithSerialNos(var SalesHeader: Record "Sales Header"; DocType: Enum "Sales Document Type"; Item: Record Item; Qty: Decimal; CustomerNo: Code[20])
    var
        SalesLine: Record "Sales Line";
        LibTrack: Codeunit "Library - Item Tracking";
        ReservEntry: Record "Reservation Entry";
        i: Integer;
        SerialName: Text;
        VatPostSetup: Record "VAT Posting Setup";
        ToGov, ToCompany, AppliedVAT, DeductVAT, ReverseCharge : Record "G/L Account";
        GenBusPostingGroup: Record "Gen. Business Posting Group";
        GenProdPostingGroup: Record "Gen. Product Posting Group";
    begin
        SalesLine := CreateSalesDoc(SalesHeader, DocType, Item, Qty, CustomerNo, ToGov, ToCompany, AppliedVAT, DeductVAT, ReverseCharge, GenBusPostingGroup, GenProdPostingGroup, 23, 23, 0, VatPostSetup."VAT Calculation Type"::"Normal VAT", VatPostSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate", VatPostSetup."PTSS SAF-T PT VAT Type Desc."::"VAT Portugal Mainland", false);
        // LibSales.CreateSalesHeader(SalesHeader, DocType, CustomerNo);
        // SalesHeader.Validate("Due Date", Today);
        // SalesHeader.Validate("Sell-to Customer No.", CustomerNo);
        // SalesHeader.Validate("Bill-to Customer No.", CustomerNo);
        // SalesHeader.Validate("Shipment Date", CalcDate('<+1D>', WorkDate()));
        // SalesHeader.Modify();
        // LibSales.CreateSalesLine(SalesLine, SalesHeader, Enum::"Sales Line Type"::Item, Item."No.", Qty);

        i := 0;
        SerialName := 'SERIAL';
        repeat
            LibTrack.CreateSalesOrderItemTracking(ReservEntry, SalesLine, SerialName + format(i), '', 1);
            i += 1;
        until i = Qty;
    end;

    procedure CreateGLAccount(var GLAcc: Record "G/L Account"; AccNo: Text)
    begin
        GLAcc.Init;
        GLAcc.Validate("No.", AccNo);
        GLAcc.Validate(Name, AccNo);
        GLAcc.Insert(True);
        GLAcc.Validate("PTSS Income Stmt. Bal. Acc.", Format(111));
        GLAcc.Modify();
    end;

    procedure CreateCashFlowPlan(var CashFlowPlan: Record "PTSS Cash-Flow Plan")
    begin
        CashFlowPlan.Init();
        CashFlowPlan."No." := LibUtil.GenerateRandomText(10);
        CashFlowPlan.Insert();
    end;

    procedure CreateStampDutyGeneralTable(var StampDuty: Record "PTSS Stamp Duty General Table")
    var
        GLAcc: Record "G/L Account";
    begin
        StampDuty.Init;
        StampDuty."No." := LibUtil.GenerateRandomCode(1, Database::"PTSS Stamp Duty General Table");
        StampDuty.Description := LibUtil.GenerateRandomText(4);
        StampDuty.Amount := 5.0;
        StampDuty."Stamp Duty Account No." := TesterHelper.CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
        StampDuty.Insert(True);
    end;

    procedure CreateBPTerritory(var BPTerritory: Record "PTSS BP Territory")
    begin
        BPTerritory.Init;
        BPTerritory.Code := LibUtil.GenerateRandomCodeWithLength(1, Database::"PTSS BP Territory", 3);
        BPTerritory.Description := LibUtil.GenerateRandomText(5);
        BPTerritory.Insert();
    end;

    procedure CreateBPAccountType(var BPAccType: Record "PTSS BP Account Type")
    begin
        BPAccType.Init;
        BPAccType.Code := LibUtil.GenerateRandomCodeWithLength(1, Database::"PTSS BP Account Type", 1);
        BPAccType.Insert();
    end;

    procedure CreateBPStatistic(var BPStatistic: Record "PTSS BP Statistic")
    begin
        BPStatistic.Init;
        BPStatistic.Code := LibUtil.GenerateRandomCodeWithLength(1, Database::"PTSS BP Statistic", 1);
        BPStatistic.Insert();
    end;

    procedure CreateInventoryPostingSetup(var InvPostingSetup: Record "Inventory Posting Setup"; var GainsAcc: Record "G/L Account"; var LossesAcc: Record "G/L Account")
    var
        InvPostGrp: Record "Inventory Posting Group";
        Loc: Record Location;
    begin
        LibInv.CreateInventoryPostingGroup(InvPostGrp);
        // LibInv.CreateInventoryPostingSetup(InvPostingSetup, WareHouseLib.CreateLocation(Loc), InvPostGrp.Code);
        CreateAuxGLAcc(GainsAcc, Format(LibRandom.RandIntInRange(1000, 4999)));
        CreateAuxGLAcc(LossesAcc, Format(LibRandom.RandIntInRange(1000, 4999)));
        CreateInventoryPostingSetupGainsLosses(InvPostingSetup, WareHouseLib.CreateLocation(Loc), InvPostGrp.Code, GainsAcc."No.", LossesAcc."No.");
        // InvPostingSetup.Validate("PTSS Gains in Inventory", GainsAcc."No.");
        // InvPostingSetup.Validate("PTSS Losses in Inventory", LossesAcc."No.");
        //InvPostingSetup.Modify();
    end;

    procedure CreateVendorBankAccEUR(VendorNo: Code[20]; var VendorBankAcc: Record "Vendor Bank Account")
    begin
        CreateVendorBankAccount(VendorBankAcc, VendorNo, LibUtil.GenerateRandomCode20(2, Database::"Vendor Bank Account"));
        VendorBankAcc.Validate(IBAN, 'PT50000727896602262246181');
        VendorBankAcc."Country/Region Code" := 'PT';
        VendorBankAcc.Validate("Currency Code", 'EUR');
        VendorBankAcc.Modify();
    end;

    #endregion

    //##################################################################################################################################

    #region jalmeida
    internal procedure CreateCurrency(var Currency: Record Currency)
    var
        CurrencyExchangeRate: Record "Currency Exchange Rate";
    begin
        Currency.Init();
        Currency.validate(Code, LibUtil.GenerateRandomCodeWithLength(Currency.FieldNo(Code), Database::Currency, 3));
        Currency.validate("Unrealized Gains Acc.", '7887');
        Currency.validate("Realized Gains Acc.", '7887');
        Currency.validate("Unrealized Losses Acc.", '6887');
        Currency.validate("Realized Losses Acc.", '6887');
        Currency.Insert();

        CreateCurrencyExchangeRate(CurrencyExchangeRate, Currency);
    end;

    internal procedure CreateCustomerSAFTwithPostingGroup(var Customer: Record Customer; var CustPostGroup: Record "Customer Posting Group")
    begin
        TesterHelper.InitializeCustomerForSAFT(Customer, GenerateRandomPTNIF());
        CreateCustomerPostingSetupAndAssignToCustomer(CustPostGroup, Customer, 10);
    end;

    internal procedure CreateCustomerPostingSetupAndAssignToCustomer(var CustPostGroup: Record "Customer Posting Group"; var Customer: Record Customer; sizeofCPG: Integer)
    begin
        if Customer."No." = '' then
            LibSales.CreateCustomer(Customer);

        if CustPostGroup.Code = '' then
            CreateCustomerPostingGroup(CustPostGroup, sizeofCPG);

        Customer.Validate("Customer Posting Group", CustPostGroup.Code);
        customer.Modify()
    end;


    procedure CreateCustomerPostingGroup(var CustomerPostingGroup: Record "Customer Posting Group"; sizeof: Integer)
    var
        ChartAcc: Record "G/L Account";
    begin
        CustomerPostingGroup.Init();
        CustomerPostingGroup.Validate(Code, 'F' + LibUtil.GenerateRandomAlphabeticText(sizeof, 1));
        CustomerPostingGroup.Validate("Receivables Account", TesterHelper.CreateGLAccount(ChartAcc, ChartAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
        CustomerPostingGroup.Validate("Invoice Rounding Account", LibERM.CreateGLAccountWithSalesSetup);
        CustomerPostingGroup.Validate("Debit Rounding Account", TesterHelper.CreateGLAccount(ChartAcc, ChartAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
        CustomerPostingGroup.Validate("Credit Rounding Account", TesterHelper.CreateGLAccount(ChartAcc, ChartAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
        CustomerPostingGroup.Validate("Payment Disc. Debit Acc.", TesterHelper.CreateGLAccount(ChartAcc, ChartAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
        CustomerPostingGroup.Validate("Payment Disc. Credit Acc.", TesterHelper.CreateGLAccount(ChartAcc, ChartAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
        CustomerPostingGroup.Validate("Payment Tolerance Debit Acc.", TesterHelper.CreateGLAccount(ChartAcc, ChartAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
        CustomerPostingGroup.Validate("Payment Tolerance Credit Acc.", TesterHelper.CreateGLAccount(ChartAcc, ChartAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
        CustomerPostingGroup.Validate("Debit Curr. Appln. Rndg. Acc.", TesterHelper.CreateGLAccount(ChartAcc, ChartAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
        CustomerPostingGroup.Validate("Credit Curr. Appln. Rndg. Acc.", TesterHelper.CreateGLAccount(ChartAcc, ChartAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
        CustomerPostingGroup.Validate("Interest Account", TesterHelper.CreateGLAccount(ChartAcc, ChartAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
        CustomerPostingGroup.Validate("Additional Fee Account", TesterHelper.CreateGLAccount(ChartAcc, ChartAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
        CustomerPostingGroup.Validate("Add. Fee per Line Account", TesterHelper.CreateGLAccount(ChartAcc, ChartAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
        CustomerPostingGroup.Insert(true);
    end;

    local procedure CreateInventoryPostingSetupGainsLosses(var InventoryPostingSetup: Record "Inventory Posting Setup"; LocationCode: Code[10]; PostingGroupCode: Code[20]; GainsAcc: Code[20]; LossesAcc: Code[20])
    begin
        Clear(InventoryPostingSetup);
        InventoryPostingSetup.Init();
        InventoryPostingSetup.Validate("Location Code", LocationCode);
        InventoryPostingSetup.Validate("Invt. Posting Group Code", PostingGroupCode);
        InventoryPostingSetup.Validate("PTSS Losses in Inventory", LossesAcc);
        InventoryPostingSetup.Validate("PTSS Gains in Inventory", GainsAcc);
        InventoryPostingSetup.Insert();
    end;

    internal procedure GenerateRandomPTNIF(): Text[20]
    begin
        exit(format(LibRandom.RandIntInRange(100000000, 999999999)));
    end;

    procedure CreateCustomerBankAccount(var CustBankAcc: Record "Customer Bank Account"; CustomerNo: Code[20]; codeBank: Code[20])
    begin
        CustBankAcc.Init();
        CustBankAcc.Validate("Customer No.", CustomerNo);
        CustBankAcc.Validate(Code, CodeBank);
        CustBankAcc.Insert();
    end;

    internal procedure CreateMultipleSalesOrderAndPost(NumberOfOrders: Integer; SalesHeader: Record "Sales Header"; SalesDocumentType: Enum "Sales Document Type"; Item: Record Item; quantity: Integer; No: Code[20]; ship: Boolean; invoice: Boolean; newCustPostGroup: Boolean; sizeofCPG: Integer; DirectDebit: Boolean; CreateVatSetup: Boolean)
    var
        i: Integer;
        CustPostGroup: Record "Customer Posting Group";
        Customer: REcord Customer;
        SalesRec: Record "Sales & Receivables Setup";
    begin
        if newCustPostGroup then begin
            Customer.Get(No);
            CreateCustomerPostingSetupAndAssignToCustomer(CustPostGroup, Customer, sizeofCPG);
        end;

        case SalesDocumentType of
            SalesDocumentType::"PTSS Debit Memo":
                begin
                    SalesRec.get();
                    SalesRec."Posted Invoice Nos." := SalesRec."PTSS Posted Debit Memo Nos.";
                    SalesRec."Invoice Nos." := SalesRec."PTSS Debit Memo Nos.";
                    SalesRec.modify();

                    if NumberOfOrders > 1 then begin
                        i := NumberOfOrders;
                        repeat
                            SalesDocumentType := SalesDocumentType::Invoice;

                            CreateSalesDocForNonExistingItems(SalesHeader, SalesDocumentType, Item, quantity, No, DirectDebit, CreateVatSetup);
                            PostSalesDebitMemo(SalesHeader);
                            i -= 1;

                        until i = 0;
                        exit;
                    end else begin
                        CreateSalesDocForNonExistingItems(SalesHeader, SalesDocumentType, Item, quantity, No, DirectDebit, CreateVatSetup);
                        PostSalesDebitMemo(SalesHeader);
                    end;
                end;
            SalesDocumentType::Invoice:
                begin
                    if NumberOfOrders > 1 then begin
                        i := NumberOfOrders;
                        repeat
                            CreateSalesDocForNonExistingItems(SalesHeader, SalesDocumentType, Item, quantity, No, DirectDebit, CreateVatSetup);
                            PostSalesDocument(SalesHeader, ship, invoice);
                            i -= 1;

                        until i = 0;
                    end else begin
                        CreateSalesDocForNonExistingItems(SalesHeader, SalesDocumentType, Item, quantity, No, DirectDebit, CreateVatSetup);
                        PostSalesDocument(SalesHeader, ship, invoice);
                    end;
                end;
            SalesDocumentType::"Credit Memo":
                begin
                    if NumberOfOrders > 1 then begin
                        i := NumberOfOrders;
                        repeat
                            CreateSalesDocForNonExistingItems(SalesHeader, SalesDocumentType, Item, quantity, No, DirectDebit, CreateVatSetup);
                            PostSalesDocument(SalesHeader, ship, invoice);
                            i -= 1;

                        until i = 0;
                    end else begin
                        CreateSalesDocForNonExistingItems(SalesHeader, SalesDocumentType, Item, quantity, No, DirectDebit, CreateVatSetup);
                        PostSalesDocument(SalesHeader, ship, invoice);
                    end;
                end;
            SalesDocumentType::Order:
                begin
                    if NumberOfOrders > 1 then begin
                        i := NumberOfOrders;
                        repeat
                            CreateSalesDocForNonExistingItems(SalesHeader, SalesDocumentType, Item, quantity, No, DirectDebit, CreateVatSetup);
                            PostSalesDocument(SalesHeader, ship, invoice);
                            i -= 1;

                        until i = 0;
                    end else begin
                        CreateSalesDocForNonExistingItems(SalesHeader, SalesDocumentType, Item, quantity, No, DirectDebit, CreateVatSetup);
                        PostSalesDocument(SalesHeader, ship, invoice);
                    end;
                end;
        end;
    end;



    procedure AddSellToContactNoToDocumentHeader(var SalesHeader: Record "Sales Header"; var Customer: Record "Customer")
    Var
        Contact: Record "Contact";
    begin
        if Customer."Primary Contact No." <> '' then begin
            Contact.get(Customer."Primary Contact No.");
        end else begin
            CreateContactNo(Contact, Contact.Type::Person);
            Customer.Validate("Primary Contact No.", Contact."No.");
        end;
        SalesHeader.validate("Sell-to Contact No.", Contact."No.");
        salesheader.Modify(true);
        Customer.Modify(true);
    end;

    procedure CreateSalesDocForNonExistingItems(var SalesHeader: Record "Sales Header"; DocType: Enum "Sales Document Type"; Item: Record Item;
                                                                                                     Qty: Decimal;
                                                                                                     CustomerNo: Code[20];
                                                                                                     "direct debit": boolean;
                                                                                                     CreateVatSetup: Boolean)
    var
        SalesLine: Record "Sales Line";
        Customer: Record Customer;
        SalesRec: Record "Sales & Receivables Setup";
        Currency: REcord Currency;
        PaymentTerms: Record "Payment Terms";
        SEPADD: Record "SEPA Direct Debit Mandate";
    begin
        SalesRec.Get();
        LibSales.CreateSalesHeader(SalesHeader, DocType, CustomerNo);
        Customer.Get(CustomerNo);
        SalesHeader.Validate("Due Date", Today);
        SalesHeader.Validate("Sell-to Customer No.", CustomerNo);
        SalesHeader.Validate("Bill-to Customer No.", CustomerNo);
        SalesHeader.RecallModifyAddressNotification(SalesHeader.GetModifyBillToCustomerAddressNotificationId());
        if "direct Debit" then begin
            CreateEuroCurrency(Currency);
            CreatePaymentTerms(PaymentTerms, '10D');
            SEPADD.SetRange("Customer No.", CustomerNo);
            SEPADD.FindFirst();
            SalesHeader."Direct Debit Mandate ID" := SEPADD.ID;
            SalesHeader.Validate("Currency Code", currency.Code);
            SalesHeader.Validate("Payment Terms Code", PaymentTerms.Code);
        end;
        SalesHeader.Validate("Shipment Date", CalcDate('<+1D>', WorkDate()));
        SalesHeader.Modify();

        CreateSalesLineWithShipmentDate(SalesLine, SalesHeader, Enum::"Sales Line Type"::Item, Item, SalesHeader."Shipment Date", Qty, false, Customer, CreateVatSetup);
    end;

    internal procedure CreateEuroCurrency(var currency: Record Currency)
    var
        CurrencyExchange: REcord "Currency Exchange Rate";
    begin
        if not currency.Get('EUR') then begin
            Currency.Init();
            Currency.Validate(Code, 'EUR');
            currency.Validate(Symbol, '€');
            Currency.Insert(true);
            CurrencyExchange.Init();
            CurrencyExchange.Validate("Currency Code", currency.Code);
            CurrencyExchange.Validate("Exchange Rate Amount", 1);
            CurrencyExchange.Validate("Relational Exch. Rate Amount", 1);
            CurrencyExchange.Insert();
        end else
            currency.Get('EUR');

    end;

    internal procedure CreatePaymentTerms(var PaymentTerms: Record "Payment Terms"; DateFormula1: Text)
    var
        dateFormula: DateFormula;
    begin
        Evaluate(dateFormula, DateFormula1);
        PaymentTerms.Init();
        PaymentTerms.Validate(Code, LibUtil.GenerateRandomText(4));
        PaymentTerms.Validate("Due Date Calculation", dateFormula);
        PaymentTerms.Validate(Description, LibUtil.GenerateRandomText(30));
        PaymentTerms.Insert();
    end;

    procedure CreateSalesLineWithShipmentDate(var SalesLine: Record "Sales Line"; var SalesHeader: Record "Sales Header"; Type: Enum "Sales Line Type"; Item: Record Item;
                                                                                                                                    ShipmentDate: Date;
                                                                                                                                    Quantity: Decimal; HasDiscount: Boolean; var Customer: Record Customer; CreateVatSetup: Boolean)
    var
        UnitofMeasure: REcord "Unit of Measure";
        VATPostSetup: Record "VAT Posting Setup";
        VATProdPostGrp: Record "VAT Product Posting Group";
        VATBusPostGrp: REcord "VAT Business Posting Group";
        genPostSetup: Record "General Posting Setup";
        GenProdPostGrp: Record "Gen. Product Posting Group";
        currencyExchenageRate: Record "Currency Exchange Rate";
        currency: Record Currency;
        RandomUnitPrice, ArrayVATPercentage : Decimal;
        VATOptions: Integer;
        InventorySetup: Record "Inventory Setup";
        Location: Record Location;
    begin
        LibSales.CreateSalesLineSimple(SalesLine, SalesHeader);

        LibInv.CreateUnitOfMeasureCode(UnitofMeasure);
        if Item."No." = '' then begin
            InventorySetup.FindSet();
            if InventorySetup."Location Mandatory" then begin
                Location.FindLast();
                CreateItemWithInventoryForLocation(Item, Quantity, Location)
            end else begin
                CreateItemWithInventory(Item, Quantity, Customer, CreateVatSetup, 0, Random(4));
            end;
        end;

        VATProdPostGrp.get(Item."VAT Prod. Posting Group");
        VATBusPostGrp.get(Customer."VAT Bus. Posting Group");

        if not VATPostSetup.get(VATBusPostGrp.code, VATProdPostGrp.code) then begin
            VATOptions := Random(4);

            case VATOptions of
                1:// Normal tax rate
                    begin
                        CreateVATPostingSetupLineWithVatPercentage(VATPostSetup, VATProdPostGrp, VATBusPostGrp, VATPostSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate");
                    end;
                2:// Intermediate tax rate
                    begin
                        CreateVATPostingSetupLineWithVatPercentage(VATPostSetup, VATProdPostGrp, VATBusPostGrp, VATPostSetup."PTSS SAF-T PT VAT Code"::"Intermediate tax rate");
                    end;
                3:// Reduced tax rate
                    begin
                        CreateVATPostingSetupLineWithVatPercentage(VATPostSetup, VATProdPostGrp, VATBusPostGrp, VATPostSetup."PTSS SAF-T PT VAT Code"::"Reduced tax rate");
                    end;
                4:// No tax rate
                    begin
                        CreateVATPostingSetupLineWithVatPercentage(VATPostSetup, VATProdPostGrp, VATBusPostGrp, VATPostSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                    end;
            end;

        end else begin
            if (VATPostSetup."PTSS SAF-T PT VAT Code" = VATPostSetup."PTSS SAF-T PT VAT Code"::" ") then begin
                VATOptions := Random(4);

                case VATOptions of
                    1:// Normal tax rate
                        begin
                            CreateVATPostingSetupLineWithVatPercentage(VATPostSetup, VATProdPostGrp, VATBusPostGrp, VATPostSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate");
                        end;
                    2:// Intermediate tax rate
                        begin
                            CreateVATPostingSetupLineWithVatPercentage(VATPostSetup, VATProdPostGrp, VATBusPostGrp, VATPostSetup."PTSS SAF-T PT VAT Code"::"Intermediate tax rate");
                        end;
                    3:// Reduced tax rate
                        begin
                            CreateVATPostingSetupLineWithVatPercentage(VATPostSetup, VATProdPostGrp, VATBusPostGrp, VATPostSetup."PTSS SAF-T PT VAT Code"::"Reduced tax rate");
                        end;
                    4:// No tax rate
                        begin
                            CreateVATPostingSetupLineWithVatPercentage(VATPostSetup, VATProdPostGrp, VATBusPostGrp, VATPostSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                        end;
                end;
            end;
        end;
        if VATPostSetup."VAT Identifier" = '' then begin
            VATPostSetup.Validate("VAT Identifier", 'IDEN' + Format(random(99)) + VATPostSetup."VAT Prod. Posting Group");
        end;

        genPostSetup.get(customer."Gen. Bus. Posting Group", item."Gen. Prod. Posting Group");
        // VATPostSetup.FindLast();
        // VATPostSetup.get(Customer."VAT Bus. Posting Group", Item."VAT Prod. Posting Group");

        //Customer.Validate("Gen. Bus. Posting Group", genPostSetup."Gen. Bus. Posting Group");
        // Customer.Validate("VAT Bus. Posting Group", VATPostSetup."VAT Bus. Posting Group");
        // Customer.modify();
        SalesHeader."Bill-to Customer No." := Customer."No.";
        SalesHeader."VAT Bus. Posting Group" := VATPostSetup."VAT Bus. Posting Group";
        SalesHeader."Gen. Bus. Posting Group" := genPostSetup."Gen. Bus. Posting Group";
        SalesHeader.Modify();

        CreateEuroCurrency(currency);

        Item.Get(Item."No.");
        SalesLine.Validate(Type, Type);
        SalesLine.Validate("No.", Item."No.");
        //SalesLine."VAT Bus. Posting Group" := Customer."VAT Bus. Posting Group";
        salesline.Validate("Gen. Bus. Posting Group", SalesHeader."Gen. Bus. Posting Group");
        SalesLine.Validate("VAT Bus. Posting Group", VATPostSetup."VAT Bus. Posting Group");
        SalesLine.Validate("VAT Prod. Posting Group", VATPostSetup."VAT Prod. Posting Group");
        SalesLine.Validate("VAT Identifier", VATPostSetup."VAT Identifier");
        SalesLine.Validate("Shipment Date", ShipmentDate);

        if Quantity <> 0 then
            SalesLine.Validate(Quantity, Quantity);
        if Item."Unit Price" = 0 then begin
            RandomUnitPrice := Random(9999);
            SalesLine.Validate("Unit Price", RandomUnitPrice);
        end else begin
            SalesLine.Validate(Amount, Item."Unit Price");
        end;
        SalesLine.Validate("Qty. to Invoice", Quantity);
        if (SalesHeader."Document Type" = SalesHeader."Document Type"::"Credit Memo") or (SalesHeader."Document Type" = SalesHeader."Document Type"::"Return Order") then begin
            SalesLine.Validate("Qty. to Ship", 0);
            //VATPostSetup.Validate("PTSS Return VAT Acc. (Sales)", );
        end else begin
            SalesLine.Validate("Qty. to Ship", Quantity);
        end;
        if HasDiscount = true then begin
            SalesLine.Validate("Line Discount %", Random(50));
        end;
        VATPostSetup.Modify();
        SalesLine.Modify();
    end;



    procedure CreateGenJournalLineWithPostingGroup(var GenJournalLine: Record "Gen. Journal Line"; JournalTemplateName: Code[10]; JournalBatchName: Code[10]; DocumentType: Enum "Gen. Journal Document Type"; AccountType: Enum "Gen. Journal Account Type";
                                                                                                                                                                                AccountNo: Code[20];
                                                                                                                                                                                BalAccountType: Enum "Gen. Journal Account Type";
                                                                                                                                                                                BalAccount: Code[20];
                                                                                                                                                                                Amount: Decimal;
                                                                                                                                                                                PostGroup: Code[20])
    var
        GenJournalBatch: Record "Gen. Journal Batch";
        NoSeries: Record "No. Series";
        NoSeriesMgt: Codeunit NoSeriesManagement;
        RecRef: RecordRef;
        PostGroupRecRef: RecordRef;
        PostGroupFieldRef: FieldRef;
        BankAcc: REcord "Bank Account";
    begin
        // Find a balanced template/batch pair.
        GenJournalBatch.Get(JournalTemplateName, JournalBatchName);

        // Create a General Journal Entry.
        GenJournalLine.Init();
        GenJournalLine.Validate("Journal Template Name", JournalTemplateName);
        GenJournalLine.Validate("Journal Batch Name", JournalBatchName);
        RecRef.GetTable(GenJournalLine);
        GenJournalLine.Validate("Line No.", LibUtil.GetNewLineNo(RecRef, GenJournalLine.FieldNo("Line No.")));
        GenJournalLine.Insert(true);
        GenJournalLine.Validate("Posting Date", WorkDate);  // Defaults to work date.
        GenJournalLine.Validate("Document Type", DocumentType);
        GenJournalLine.Validate("Account Type", AccountType);
        GenJournalLine.Validate("Account No.", AccountNo);
        GenJournalLine.Validate(Amount, Amount);
        if NoSeries.Get(GenJournalBatch."No. Series") then
            GenJournalLine.Validate("Document No.", NoSeriesMgt.GetNextNo(GenJournalBatch."No. Series", WorkDate, false)) // Unused but required field for posting.
        else
            GenJournalLine.Validate(
              "Document No.", LibUtil.GenerateRandomCode(GenJournalLine.FieldNo("Document No."), DATABASE::"Gen. Journal Line"));
        GenJournalLine.Validate("External Document No.", GenJournalLine."Document No.");  // Unused but required for vendor posting.
        GenJournalLine.Validate("Source Code", LibERM.FindGeneralJournalSourceCode);  // Unused but required for AU, NZ builds
        GenJournalLine.Validate("Bal. Account Type", BalAccountType);
        LibERM.CreateBankAccount(BankAcc);
        GenJournalLine.Validate("Bal. Account No.", BalAccount);

        if PostGroup <> ' ' then
            GenJournalLine.Validate("Posting Group", PostGroup);

        GenJournalLine.Modify(true);
    end;

    internal procedure CreateTaxonomyCode(var Taxonomy: Record "PTSS Taxonomy Codes"; TaxonomyReference: Enum "PTSS Taxonomy Reference Enum")
    begin
        Taxonomy.Init();
        Taxonomy.Validate("Taxonomy Code", LibRandom.RandIntInRange(1000, 9999));
        Taxonomy.Validate(Description, LibUtil.GenerateRandomText(6));
        Taxonomy.Validate("Taxonomy Reference", TaxonomyReference);
        Taxonomy.Insert();
    end;

    procedure CreateVendorBankAccount(var VendorBankAcc: Record "Vendor Bank Account"; VendorNo: Code[20]; codeBank: Code[20])
    begin
        VendorBankAcc.Init();
        VendorBankAcc.Validate("Vendor No.", VendorNo);
        VendorBankAcc.Validate(Code, CodeBank);
        VendorBankAcc.Insert();
    end;

    /// <summary>
    /// Creates No series e No series line with SAF-T or GTAT code
    /// </summary>
    /// <param name="SAFT">Boolean.</param>
    /// <param name="GTAT">Boolean.</param>
    procedure CreateNoSeries(SAFT: Boolean; GTAT: Boolean; WD: Boolean; DocType: Option): Code[20]
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        NoSeriesText: Text;
        ATValidationCode: text;
        Error: Label 'SAFT and GTAT cannot be both true';
        RecRef: RecordRef;
    begin
        NoSeriesText := 'V' + LibUtil.GenerateRandomCode(1, 308);
        ATValidationCode := LibUtil.GenerateRandomAlphabeticText(8, 0);

        NoSeriesLine.SetRange("PTSS AT Validation Code", ATValidationCode);
        if NoSeriesLine.FindFirst() then begin
            repeat
                NoSeriesLine.Reset();
                ATValidationCode := LibUtil.GenerateRandomAlphabeticText(8, 0);
                NoSeriesLine.SetRange("PTSS AT Validation Code", ATValidationCode);
            until not NoSeriesLine.FindFirst();
            NoSeriesLine.Reset();
        end;

        if NoSeries.Get(NoSeriesText) then begin
            repeat
                NoSeriesText := 'V' + LibUtil.GenerateRandomCode(1, 308);
            until not NoSeries.Get(NoSeriesText);
        end;

        LibUtil.CreateNoSeries(NoSeries, true, false, false);
        if SAFT and GTAT then
            Error(Error);
        if SAFT then
            NoSeries.Validate("PTSS SAF-T Invoice Type", DocType);
        if GTAT then
            NoSeries.Validate("PTSS GTAT Document Type", DocType);
        if WD then
            NoSeries.Validate("PTSS SAF-T Working Doc Type", DocType);
        NoSeries.Modify(true);
        //LibUtil.CreateNoSeriesLine(NoSeriesLine, NoSeries.Code, NoSeriesText + '0001', NoSeriesText + '9999');

        NoSeriesLine.Init();
        NoSeriesLine."Starting Date" := Today;
        NoSeriesLine.Validate("Series Code", NoSeries.Code);
        RecRef.GetTable(NoSeriesLine);
        NoSeriesLine.Validate("Line No.", LibUtil.GetNewLineNo(RecRef, NoSeriesLine.FieldNo("Line No.")));
        NoSeriesLine.Insert(true);

        if (NoSeriesText + '00001') = '' then
            NoSeriesLine.Validate("Starting No.", PadStr(InsStr(NoSeries.Code, '0000', 3), 10))
        else
            NoSeriesLine.Validate("Starting No.", NoSeriesText + '0001');

        if (NoSeriesText + '99999') = '' then
            NoSeriesLine.Validate("Ending No.", PadStr(InsStr(NoSeries.Code, '9999', 3), 10))
        else
            NoSeriesLine.Validate("Ending No.", NoSeriesText + '9999');

        NoSeriesLine.validate("PTSS SAF-T No. Series Del.", StrLen(NoSeriesText));
        noseriesline.Validate("PTSS AT Validation Code", ATValidationCode);
        NoSeriesLine.Modify();
        exit(NoSeries.Code);
    end;

    internal procedure CreateVendorPostingSetupAndAssignToVendor(var VendorPostGroup: Record "Vendor Posting Group"; var Vendor: Record Vendor)
    begin
        if Vendor."No." = '' then
            LibPurch.CreateVendor(Vendor);

        if VendorPostGroup.Code = '' then
            LibPurch.CreateVendorPostingGroup(VendorPostGroup);

        Vendor.Validate("Vendor Posting Group", VendorPostGroup.Code);
        Vendor.Validate("Country/Region Code", 'PT');
        Vendor.Modify()
    end;

    procedure CreatePurchaseInvoiceForVendorNo(var PurchaseHeader: Record "Purchase Header"; VendorNo: Code[20]; Item: Record Item)
    var
        PurchaseLine: Record "Purchase Line";
    begin
        LibPurch.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, VendorNo);
        LibPurch.CreatePurchaseLine(PurchaseLine, PurchaseHeader, Enum::"Purchase Line Type"::Item, Item."No.", 3);
        PurchaseLine.Validate("Direct Unit Cost", LibRandom.RandDecInRange(1, 100, 2));
        PurchaseLine.Modify(true);
    end;

    procedure CreatePurchaseCreditMemoForVendorNo(var PurchaseHeader: Record "Purchase Header"; VendorNo: Code[20]; Item: Record Item)
    var
        PurchaseLine: Record "Purchase Line";
    begin
        LibPurch.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::"Credit Memo", VendorNo);
        LibPurch.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 1);
        PurchaseLine.Validate("Direct Unit Cost", LibRandom.RandDecInRange(1, 100, 2));
        PurchaseLine.Modify(true);
    end;

    procedure CreateGLAccountRandNo(var GLAcc: Record "G/L Account"; AccNo: Code[20])
    begin
        GLAcc.setrange("No.", AccNo);
        if not GLAcc.FindSet() then begin
            GLAcc.Init;
            GLAcc.Validate("No.", AccNo);
            GLAcc.Validate(Name, AccNo);
            GLAcc.Insert(True);
        end;
    end;

    internal procedure CreateItem(var Item: Record Item; VatBusPostGroup: Record "VAT Business Posting Group"; VatProdPostGroup: Record "VAT Product Posting Group")
    begin
        LibInv.CreateItemWithoutVAT(Item);
        Item.Validate("VAT Bus. Posting Gr. (Price)", VatBusPostGroup.Code);
        Item.Validate("VAT Prod. Posting Group", VatProdPostGroup.Code);
        Item.Modify();
    end;

    internal procedure CreateInventoryPostingSetup()
    var
        InvPostSetup: REcord "Inventory Posting Setup";
        InvPostGroup: REcord "Inventory Posting Group";
        Location: Record Location;
        InventoryAcc: Record "G/L Account";

    begin
        CreateLocation(Location);
        LibInv.CreateInventoryPostingGroup(InvPostGroup);
        LibInv.CreateInventoryPostingSetup(InvPostSetup, Location.Code, InvPostGroup.Code);
        CreateGLAccountRandNo(InventoryAcc, Format(LibRandom.RandIntInRange(1000, 4999)));
        InvPostSetup.Validate("Inventory Account", InventoryAcc."No.");
        InvPostSetup.Modify();
    end;

    internal procedure "Create VAT Posting Setup For Purchases VAT"(ImpVendor: Record "VAT Business Posting Group"; Gas50: Record "VAT Product Posting Group";
                                                                    IVAaPagar: Record "G/L Account";
                                                                    IVAaReceber: Record "G/L Account";
                                                                    var GenBusPostingGroup: Record "Gen. Business Posting Group";
                                                                    var GenProdPostingGroup: Record "Gen. Product Posting Group";
                                                                    VATvalue: Decimal;
                                                                    PTSS_VAT_D: Decimal;
                                                                    PTSS_VAT_ND: Decimal;
                                                                    VAT_Calculation_Type: Enum "Tax Calculation Type";
                                                                                              VAT_Code: Option;
                                                                                              VAT_Type_Desc: Option;
                                                                                              VAT_Identifier: Text)
    var
        VATSetup: REcord "VAT Posting Setup";
        GeneralPostingSetup: Record "General Posting Setup";
        PurchAcc: Record "G/L Account";

    begin
        CreateGenBusPostingGroup(GenBusPostingGroup);
        CreateGenProdPostingGroup(GenProdPostingGroup);
        Liberm.CreateGeneralPostingSetup(GeneralPostingSetup, GenBusPostingGroup.Code, GenProdPostingGroup.Code);
        CreateGLAccountRandNo(PurchAcc, Format(LibRandom.RandIntInRange(1000, 4999)));
        GeneralPostingSetup.Validate("Purch. Account", PurchAcc."No.");
        GeneralPostingSetup.Validate("PTSS Cr.M Dir. Cost Appl. Acc.", PurchAcc."No.");
        GeneralPostingSetup.Validate("Purch. Credit Memo Account", PurchAcc."No.");
        GeneralPostingSetup.Modify();


        VATSetup.Init();
        VATSetup.Validate("VAT Bus. Posting Group", ImpVendor.Code);
        VATSetup.Validate("VAT Prod. Posting Group", Gas50.code);
        VATSetup.Validate("VAT Identifier", VAT_Identifier);
        VATSetup.Validate("VAT %", VATvalue);
        VATSetup.Validate("PTSS VAT D. %", PTSS_VAT_D);
        VATSetup.Validate("PTSS VAT N.D. %", PTSS_VAT_ND);
        VATSetup.Validate("VAT Calculation Type", VAT_Calculation_Type);
        VATSetup.Validate("PTSS SAF-T PT VAT Code", VAT_Code);
        VATSetup.Validate("PTSS SAF-T PT VAT Type Desc.", VAT_Type_Desc);
        VATSetup.Validate("Purchase VAT Account", IVAaReceber."No.");
        VATSetup.Validate("Reverse Chrg. VAT Acc.", IVAaPagar."No.");
        VATSetup.Validate("PTSS Return VAT Acc. (Purch.)", IVAaPagar."No.");
        VATSetup.Insert();
    end;

    internal procedure CreatePurchaseOrderWithPurchaseLine(var PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line"; Vendor: Record Vendor; Item: REcord Item; ImpVendor: Record "VAT Business Posting Group")
    begin
        Vendor.Validate("VAT Bus. Posting Group", ImpVendor.Code);
        Vendor.Modify();
        LibPurch.CreatePurchHeader(PurchaseHeader, Enum::"Purchase Document Type"::Order, Vendor."No.");
        LibPurch.CreatePurchaseLine(PurchaseLine, PurchaseHeader, Enum::"Purchase Line Type"::Item, Item."No.", 2);
        //PurchaseLine."Unit Price (LCY)" := 100;
        PurchaseLine.Amount := LibRandom.RandInt(10);
        PurchaseLine."Direct Unit Cost" := LibRandom.RandInt(100);

        PurchaseLine.Modify();

    end;

    internal procedure CreatePurchaseInvoiceWithPurchaseLine(var PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line"; Vendor: Record Vendor; Item: REcord Item; ImpVendor: Record "VAT Business Posting Group")
    begin
        Vendor.Validate("VAT Bus. Posting Group", ImpVendor.Code);
        Vendor.Modify();
        LibPurch.CreatePurchHeader(PurchaseHeader, Enum::"Purchase Document Type"::Invoice, Vendor."No.");
        LibPurch.CreatePurchaseLine(PurchaseLine, PurchaseHeader, Enum::"Purchase Line Type"::Item, Item."No.", 2);
        //PurchaseLine."Unit Price (LCY)" := 100;
        PurchaseLine.Amount := LibRandom.RandInt(10);
        PurchaseLine."Direct Unit Cost" := LibRandom.RandInt(100);

        PurchaseLine.Modify();

    end;

    internal procedure CreatePurchaseCreditMemoWithPurchaseLine(var PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line"; Vendor: Record Vendor; Item: REcord Item; ImpVendor: Record "VAT Business Posting Group")
    begin
        Vendor.Validate("VAT Bus. Posting Group", ImpVendor.Code);
        Vendor.Modify();
        LibPurch.CreatePurchHeader(PurchaseHeader, Enum::"Purchase Document Type"::"Credit Memo", Vendor."No.");
        LibPurch.CreatePurchaseLine(PurchaseLine, PurchaseHeader, Enum::"Purchase Line Type"::Item, Item."No.", 2);
        //PurchaseLine."Unit Price (LCY)" := 100;
        PurchaseLine.Amount := LibRandom.RandInt(10);
        PurchaseLine."Direct Unit Cost" := LibRandom.RandInt(100);

        PurchaseLine.Modify();

    end;

    internal procedure CreateAccountingPeriod(AccountingPeriod: Record "Accounting Period"; Name: Text; InitDate: Date; NewFiscalYear: Boolean)
    begin
        AccountingPeriod.Init();
        AccountingPeriod.validate("Starting Date", InitDate);
        AccountingPeriod.Validate(Name, Name);
        AccountingPeriod.Validate("New Fiscal Year", NewFiscalYear);
        AccountingPeriod.Insert();
    end;

    internal procedure CreateCustomVATPostingSetup(VatBusPostGroup: Record "VAT Business Posting Group";
                                                        VatProdPostGroup: Record "VAT Product Posting Group";
                                                        ToGov: Record "G/L Account";
                                                        ToCompany: Record "G/L Account";
                                                        AppliedVAT: Record "G/L Account";
                                                        DeductVAT: Record "G/L Account";
                                                        ReverseCharge: Record "G/L Account";
                                                        var GenBusPostingGroup: Record "Gen. Business Posting Group";
                                                        var GenProdPostingGroup: Record "Gen. Product Posting Group";
                                                        VATvalue: Decimal;
                                                        PTSS_VAT_D: Decimal;
                                                        PTSS_VAT_ND: Decimal;
                                                        VAT_Calculation_Type: Enum "Tax Calculation Type";
                                                                                  VAT_Code: Option;
                                                                                  VAT_Type_Desc: Option;
                                                                                  VAT_Identifier: Text)
    var
        VATSetup: REcord "VAT Posting Setup";
        GeneralPostingSetup: Record "General Posting Setup";
        Acc: Record "G/L Account";
        VAtClause: Record "VAT Clause";
    begin
        if not GeneralPostingSetup.Get(GenBusPostingGroup.Code, GenProdPostingGroup.Code) then begin
            CreateGenBusPostingGroup(GenBusPostingGroup);
            CreateGenProdPostingGroup(GenProdPostingGroup);
            Liberm.CreateGeneralPostingSetup(GeneralPostingSetup, GenBusPostingGroup.Code, GenProdPostingGroup.Code);
        end;
        CreateGLAccountRandNo(Acc, Format(LibRandom.RandIntInRange(1000, 4999)));
        GeneralPostingSetup.Validate("Purch. Account", Acc."No.");
        GeneralPostingSetup.Validate("PTSS Cr.M Dir. Cost Appl. Acc.", Acc."No.");
        GeneralPostingSetup.Validate("Purch. Credit Memo Account", Acc."No.");
        GeneralPostingSetup.Modify();

        VATSetup.Init();
        VATSetup.Validate("VAT Bus. Posting Group", VatBusPostGroup.Code);
        VATSetup.Validate("VAT Prod. Posting Group", VatProdPostGroup.code);
        VATSetup.Validate("VAT Identifier", VAT_Identifier);
        VATSetup.Validate("VAT %", VATvalue);
        VATSetup.Validate("PTSS VAT D. %", PTSS_VAT_D);
        VATSetup.Validate("PTSS VAT N.D. %", PTSS_VAT_ND);
        VATSetup.Validate("VAT Calculation Type", VAT_Calculation_Type);
        VATSetup.Validate("PTSS SAF-T PT VAT Code", VAT_Code);
        VATSetup.Validate("PTSS SAF-T PT VAT Type Desc.", VAT_Type_Desc);
        VATSetup.Validate("PTSS Return VAT Acc. (Sales)", ToGov."No.");
        VATSetup.Validate("PTSS Return VAT Acc. (Purch.)", ToCompany."No.");
        VATSetup.Validate("Sales VAT Account", AppliedVAT."No.");
        VATSetup.Validate("Purchase VAT Account", DeductVAT."No.");
        VATSetup.Validate("Reverse Chrg. VAT Acc.", ReverseCharge."No.");

        if VATSetup."VAT Calculation Type" = VATSetup."VAT Calculation Type"::"PTSS Stamp Duty" then begin
            if not VAtClause.FindFirst() then
                CreateVATClause(VAtClause, LibUtil.GenerateRandomText(10));
            VATSetup.Validate("VAT Clause Code", VAtClause.Code);
        end;

        VATSetup.Insert();
    end;

    procedure CreateVATClause(var VATClause: Record "VAT Clause"; Code: Code[20])
    begin
        VATClause.Init();
        VATClause.Code := Code;
        VATClause.Insert();
    end;

    #endregion

    #region DavidP

    procedure PostPrepaymentCrMemoSalesOrder(salesHeader: Record "Sales Header")
    var
        SalesOrderPage: TestPage "Sales Order";
    begin
        SalesOrderPage.OpenEdit();
        SalesOrderPage.GoToRecord(SalesHeader);
        SalesOrderPage.PostPrepaymentCreditMemo.Invoke();
    end;

    procedure PostServiceDocument(var ServiceHeader: Record "Service Header"; NewShipReceive: Boolean; NewInvoice: Boolean): Code[20]
    begin
        exit(DoPostServiceDoc(ServiceHeader, NewShipReceive, NewInvoice, false));
    end;

    local procedure DoPostServiceDoc(var ServiceHeader: Record "Service Header"; NewShipReceive: Boolean; NewInvoice: Boolean; AfterPostSalesDocumentSendAsEmail: Boolean) DocumentNo: Code[20]
    var
        ServicePost: Codeunit "Service-Post";
        ServicePostPrint: Codeunit "Service-Post+Print";
        Assert: Codeunit Assert;
        NoSeriesManagement: Codeunit NoSeriesManagement;
        NoSeriesCode: Code[20];
    begin
        with ServiceHeader do begin
            // Validate(Ship, NewShipReceive);
            // Validate(Receive, NewShipReceive);
            // Validate(Invoice, NewInvoice);

            case "Document Type" of
                "Document Type"::Invoice:
                    NoSeriesCode := "Posting No. Series";  // posted sales invoice.
                "Document Type"::Order:
                    if NewShipReceive and not NewInvoice then
                        // posted sales shipment.
                        NoSeriesCode := "Shipping No. Series"
                    else
                        NoSeriesCode := "Posting No. Series";  // posted sales invoice.
                "Document Type"::"Credit Memo":
                    NoSeriesCode := "Posting No. Series";  // posted sales credit memo.
                else
                    Assert.Fail(StrSubstNo(WrongDocumentTypeErr, "Document Type"));
            end;
        end;

        if ServiceHeader."Posting No." = '' then begin
            DocumentNo := NoSeriesManagement.GetNextNo(NoSeriesCode, Today, true);
            ServiceHeader."Posting No." := DocumentNo;
        end else begin
            DocumentNo := ServiceHeader."Posting No.";
        end;

        Clear(ServicePost);
        ServicePost.Run(ServiceHeader);
    end;

    internal procedure CreateMultipleRandomReceiptsWithDiscountNWithholdingNPost(NumberOfOrders: Integer; SalesHeader: Record "Sales Header"; SalesDocumentType: Enum "Sales Document Type"; Customer: REcord Customer)
    var
        i: Integer;

        SalesLine: Record "Sales Line";
        WithholdingCode: Record "PTSS Withholding Tax Codes";
        DocLineNumber, DocCalculationType : Integer;
        WithholdingCode1, WithholdingCode2 : Decimal;
        WithholdingTaxReturn: Codeunit "PTSS Withholding Tax Return";
        VATPostingSetup: Record "VAT Posting Setup";
        VATBusPostingGroup: Record "VAT Business Posting Group";
        VATProdPostingGroup: Record "VAT Product Posting Group";
        GLAccount: Record "G/L Account";
        IsDebit: Boolean;
        Item: Record Item;

        Quantity: Integer;
        Discount: Decimal;
        UnitPrice: Decimal;
    begin
        if SalesDocumentType = SalesDocumentType::"PTSS Debit Memo" then begin
            IsDebit := true;
            SalesDocumentType := SalesDocumentType::Invoice;
        end;

        if NumberOfOrders > 1 then begin
            i := NumberOfOrders;
            repeat
                // DocCalculationType = 1 => Doc with no discount and no Withholding Tax, random VAT and random number of lines
                // DocCalculationType = 2 => Doc with discount and no Withholding Tax, random VAT and random number of lines
                // DocCalculationType = 3 => Doc no discount and with Withholding Tax, random VAT and random number of lines
                // DocCalculationType = 4 => Doc with discount and with Withholding Tax, random VAT and random number of lines
                DocCalculationType := Random(4);

                case DocCalculationType of
                    1:
                        begin
                            DocLineNumber := Random(10);
                            CreateSalesDocSimpleBillToDefaultCustomer(SalesHeader, SalesDocumentType, Enum::"Sales Bill-to Options"::"Default (Customer)", Customer."No.");
                            repeat
                                CreateItemWithInventory(Item, 9999, Customer, false, 0, 1);
                                Quantity := Random(10);
                                Discount := 0;
                                UnitPrice := random(99999);

                                SalesLine.get(SalesHeader."Document Type", SalesHeader."No.", CreateReceiptDocFromSalesLineAndBalAcc(SalesHeader, Customer, Item, Quantity, Discount, UnitPrice, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate"));
                                SalesLine.reset();
                                DocLineNumber -= 1;
                            until DocLineNumber = 0;

                            if IsDebit then begin
                                PostSalesDebitMemo(SalesHeader);
                            end else begin
                                PostSalesDocument(SalesHeader, true, true);
                            end;
                            i -= 1;
                        end;
                    2:
                        begin
                            DocLineNumber := Random(10);
                            CreateSalesDocSimpleBillToDefaultCustomer(SalesHeader, SalesDocumentType, Enum::"Sales Bill-to Options"::"Default (Customer)", Customer."No.");
                            repeat
                                CreateItemWithInventory(Item, 9999, Customer, false, 0, 1);
                                Quantity := Random(10);
                                Discount := random(50);
                                UnitPrice := random(99999);

                                CreateReceiptDocFromSalesLineAndBalAcc(SalesHeader, Customer, Item, Quantity, Discount, UnitPrice, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate");
                                DocLineNumber -= 1;
                            until DocLineNumber = 0;

                            if IsDebit then begin
                                PostSalesDebitMemo(SalesHeader);
                            end else begin
                                PostSalesDocument(SalesHeader, true, true);
                            end;
                            i -= 1;
                        end;
                    3:
                        begin
                            DocLineNumber := Random(10);
                            CreateSalesDocSimpleBillToDefaultCustomer(SalesHeader, SalesDocumentType, Enum::"Sales Bill-to Options"::"Default (Customer)", Customer."No.");
                            repeat
                                CreateItemWithInventory(Item, 9999, Customer, false, 0, 1);
                                WithholdingCode1 := Random(50);
                                WithholdingCode2 := Random(50);

                                Quantity := Random(10);
                                Discount := 0;
                                UnitPrice := random(99999);

                                SalesLine.get(SalesHeader."Document Type", SalesHeader."No.", CreateReceiptDocFromSalesLineAndBalAcc(SalesHeader, Customer, Item, Quantity, Discount, UnitPrice, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate"));

                                TesterHelper.AddDiscountAndWithholdingTaxToTheSalesLine(SalesHeader, SalesLine, SalesLine."Line No.", Discount, true, WithholdingCode1, WithholdingCode2);

                                if WithholdingCode1 <> 0 then begin
                                    WithholdingCode.Get(SalesHeader."PTSS Withholding Tax Code");
                                    GLAccount.get(WithholdingCode."G/L Account");
                                    if not VATPostingSetup.get(Customer."VAT Bus. Posting Group", GLAccount."VAT Prod. Posting Group") then begin
                                        VATBusPostingGroup.Get(Customer."VAT Bus. Posting Group");
                                        VATProdPostingGroup.Get(GLAccount."VAT Prod. Posting Group");
                                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProdPostingGroup, VATBusPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                                    end;
                                    WithholdingCode.Reset();
                                end;
                                if WithholdingCode2 <> 0 then begin
                                    WithholdingCode.Get(SalesHeader."PTSS Withholding Tax Code 2");
                                    GLAccount.get(WithholdingCode."G/L Account");
                                    if not VATPostingSetup.get(Customer."VAT Bus. Posting Group", GLAccount."VAT Prod. Posting Group") then begin
                                        VATBusPostingGroup.Get(Customer."VAT Bus. Posting Group");
                                        VATProdPostingGroup.Get(GLAccount."VAT Prod. Posting Group");
                                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProdPostingGroup, VATBusPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                                    end;
                                    WithholdingCode.Reset();
                                end;
                                DocLineNumber -= 1;
                            until DocLineNumber = 0;

                            SalesLine.Reset();
                            SalesLine.SetRange(SalesLine."PTSS Withholding Tax", true);
                            if SalesLine.FindSet() then begin
                                WithholdingTaxReturn.CreateSalesWithholdingTax(SalesHeader);
                            end;
                            SalesLine.reset();

                            if IsDebit then begin
                                PostSalesDebitMemo(SalesHeader);
                            end else begin
                                PostSalesDocument(SalesHeader, true, true);
                            end;
                            i -= 1;
                        end;
                    4:
                        begin
                            DocLineNumber := Random(10);
                            CreateSalesDocSimpleBillToDefaultCustomer(SalesHeader, SalesDocumentType, Enum::"Sales Bill-to Options"::"Default (Customer)", Customer."No.");
                            repeat
                                CreateItemWithInventory(Item, 9999, Customer, false, 0, 1);
                                WithholdingCode1 := Random(50);
                                WithholdingCode2 := Random(50);

                                Quantity := Random(10);
                                Discount := random(50);
                                UnitPrice := random(99999);

                                SalesLine.get(SalesHeader."Document Type", SalesHeader."No.", CreateReceiptDocFromSalesLineAndBalAcc(SalesHeader, Customer, Item, Quantity, Discount, UnitPrice, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate"));

                                TesterHelper.AddDiscountAndWithholdingTaxToTheSalesLine(SalesHeader, SalesLine, SalesLine."Line No.", Discount, true, WithholdingCode1, WithholdingCode2);
                                if WithholdingCode1 <> 0 then begin
                                    WithholdingCode.Get(SalesHeader."PTSS Withholding Tax Code");
                                    GLAccount.get(WithholdingCode."G/L Account");
                                    if not VATPostingSetup.get(Customer."VAT Bus. Posting Group", GLAccount."VAT Prod. Posting Group") then begin
                                        VATBusPostingGroup.Get(Customer."VAT Bus. Posting Group");
                                        VATProdPostingGroup.Get(GLAccount."VAT Prod. Posting Group");
                                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProdPostingGroup, VATBusPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                                    end;
                                    WithholdingCode.Reset();
                                end;
                                if WithholdingCode2 <> 0 then begin
                                    WithholdingCode.Get(SalesHeader."PTSS Withholding Tax Code 2");
                                    GLAccount.get(WithholdingCode."G/L Account");
                                    if not VATPostingSetup.get(Customer."VAT Bus. Posting Group", GLAccount."VAT Prod. Posting Group") then begin
                                        VATBusPostingGroup.Get(Customer."VAT Bus. Posting Group");
                                        VATProdPostingGroup.Get(GLAccount."VAT Prod. Posting Group");
                                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProdPostingGroup, VATBusPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                                    end;
                                    WithholdingCode.Reset();
                                end;


                                DocLineNumber -= 1;
                            until DocLineNumber = 0;

                            SalesLine.Reset();
                            SalesLine.SetRange(SalesLine."PTSS Withholding Tax", true);
                            if SalesLine.FindSet() then begin
                                WithholdingTaxReturn.CreateSalesWithholdingTax(SalesHeader);
                            end;
                            SalesLine.reset();

                            if IsDebit then begin
                                PostSalesDebitMemo(SalesHeader);
                            end else begin
                                PostSalesDocument(SalesHeader, true, true);
                            end;
                            i -= 1;
                        end;
                end;
            until i = 0;
        end;
    end;

    procedure CreateReceiptDocFromSalesLineAndBalAcc(var SalesHeader: Record "Sales Header"; Customer: Record Customer; Item: Record Item; Quantity: Decimal; Discount: Decimal; UnitPrice: Decimal; SAFTPTVATCode: Option): Integer
    var
        VATPostSetup: Record "VAT Posting Setup";
        PaymentMethod: Record "Payment Method";
        GLAcc: Record "G/L Account";
        SalesLine: Record "Sales Line";
    begin
        TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);

        CreatePaymentMethod(PaymentMethod);
        PaymentMethod.Validate("Bal. Account No.", GLAcc."No.");
        PaymentMethod.Modify(true);


        SalesLine.get(SalesHeader."Document Type", SalesHeader."No.", CreateSalesLineWithDifferentDiscountAndVATTax(SalesHeader, Enum::"Sales Line Type"::Item, Item, Quantity, Customer, SAFTPTVATCode, Discount, UnitPrice));
        SalesHeader.Validate("Payment Method Code", PaymentMethod.Code);
        SalesHeader.Modify(true);
        exit(SalesLine."Line No.");
    end;

    internal procedure CreateMultipleRandomPurchWithDiscountNWithholdingNPost(NumberOfOrders: Integer; Vendor: Record Vendor; purchaseHeader: Record "purchase Header"; purchaseDocumentType: Enum "purchase Document Type"; Item: Record Item; IsIntegretion: Boolean; IsRecovery: Boolean; ToShipReceive: Boolean; ToInvoice: Boolean)
    var
        i: Integer;
        purchaseLine: Record "purchase Line";
        WithholdingCode: Record "PTSS Withholding Tax Codes";
        DocLineNumber, DocCalculationType : Integer;
        WithholdingCode1, WithholdingCode2 : Code[20];
        WithholdingNo1, WithholdingNo2 : Decimal;
        DiscountPercentage, UnitPrice : Decimal;
        quantity: Integer;
        WithholdingTaxReturn: Codeunit "PTSS Withholding Tax Return";
        VATPostingSetup: Record "VAT Posting Setup";
        VATBusPostingGroup: Record "VAT Business Posting Group";
        VATProdPostingGroup: Record "VAT Product Posting Group";
        GLAccount: Record "G/L Account";
        ReturnShipmentHeader: Record "Return Shipment Header";
        NotReturnOrderError: label 'Document Type isnt a Return Order';
    begin
        if NumberOfOrders > 1 then begin
            i := NumberOfOrders;

            WithholdingNo1 := LibRandom.RandDecInDecimalRange(0.5, 50, 2);
            WithholdingNo2 := LibRandom.RandDecInDecimalRange(0.5, 50, 2);
            WithholdingCode1 := Format(WithholdingNo1);
            WithholdingCode2 := Format(WithholdingNo2);

            CreateWithholdingCode(WithholdingCode, true, WithholdingNo1, WithholdingNo2);

            if IsIntegretion and (purchaseDocumentType = purchaseDocumentType::"return order") then begin
                CreatePurchaseDocSimpleForVendorNo(PurchaseHeader, Enum::"Purchase Document Type"::"return order", Vendor."No.");
                CreatePurchLineWithDifferentDiscountAndVATTax(PurchaseHeader, Enum::"Purchase Line Type"::Item, Item, 1, Vendor, 23, 0, 10);
                PostPurchaseDocument(PurchaseHeader, true, true);
                // ReturnShipmentHeader.get(PurchaseHeader."Last Posting No.");
                ReturnShipmentHeader.SetRange("Return Order No.", PurchaseHeader."No.");
                ReturnShipmentHeader.FindSet();
            end else begin
                if purchaseDocumentType <> purchaseDocumentType::"return order" then begin
                    error(NotReturnOrderError);
                end;
            end;

            repeat
                // DocCalculationType = 1 => Doc with no discount and no Withholding Tax, random VAT and random number of lines
                // DocCalculationType = 2 => Doc with discount and no Withholding Tax, random VAT and random number of lines
                // DocCalculationType = 3 => Doc no discount and with Withholding Tax, random VAT and random number of lines
                // DocCalculationType = 4 => Doc with discount and with Withholding Tax, random VAT and random number of lines
                // DocCalculationType := Random(4);
                DocCalculationType := Random(2);
                CreatePurchaseDocSimpleForVendorNo(PurchaseHeader, purchaseDocumentType, Vendor."No.");

                if DocCalculationType in [3, 4] then begin
                    if WithholdingNo1 <> 0 then begin
                        WithholdingCode.Get(WithholdingCode1);
                        GLAccount.get(WithholdingCode."G/L Account");
                        if not VATPostingSetup.get(Vendor."VAT Bus. Posting Group", GLAccount."VAT Prod. Posting Group") then begin
                            VATBusPostingGroup.Get(Vendor."VAT Bus. Posting Group");
                            VATProdPostingGroup.Get(GLAccount."VAT Prod. Posting Group");
                            CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProdPostingGroup, VATBusPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                        end;
                        WithholdingCode.Reset();
                        VATProdPostingGroup.Reset();
                        VATBusPostingGroup.reset();
                        VATPostingSetup.Reset();
                        GLAccount.Reset();
                    end;
                    if WithholdingNo2 <> 0 then begin
                        WithholdingCode.Get(WithholdingCode2);
                        GLAccount.get(WithholdingCode."G/L Account");
                        if not VATPostingSetup.get(Vendor."VAT Bus. Posting Group", GLAccount."VAT Prod. Posting Group") then begin
                            VATBusPostingGroup.Get(Vendor."VAT Bus. Posting Group");
                            VATProdPostingGroup.Get(GLAccount."VAT Prod. Posting Group");
                            CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProdPostingGroup, VATBusPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                        end;
                        WithholdingCode.Reset();
                        VATProdPostingGroup.Reset();
                        VATBusPostingGroup.reset();
                        VATPostingSetup.Reset();
                        GLAccount.Reset();
                    end;
                end;

                case DocCalculationType of
                    1:
                        begin
                            DocLineNumber := Random(10);
                            repeat
                                DiscountPercentage := 0;
                                UnitPrice := LibRandom.RandDecInDecimalRange(0.5, 500, 2);
                                quantity := Random(10);
                                CreatePurchLineWithDifferentDiscountAndVATTax(PurchaseHeader, Enum::"Purchase Line Type"::Item, Item, quantity, Vendor, 23, DiscountPercentage, UnitPrice);
                                DocLineNumber -= 1;
                            until DocLineNumber = 0;
                        end;
                    2:
                        begin
                            DocLineNumber := Random(10);
                            repeat
                                DiscountPercentage := LibRandom.RandDecInDecimalRange(1, 50, 2);
                                UnitPrice := LibRandom.RandDecInDecimalRange(0.5, 500, 2);
                                quantity := Random(10);
                                CreatePurchLineWithDifferentDiscountAndVATTax(PurchaseHeader, Enum::"Purchase Line Type"::Item, Item, quantity, Vendor, 23, DiscountPercentage, UnitPrice);
                                DocLineNumber -= 1;
                            until DocLineNumber = 0;
                        end;
                    3:
                        begin
                            DocLineNumber := Random(10);
                            repeat
                                PurchaseHeader.Validate("PTSS Withholding Tax Code 1", WithholdingCode1);
                                PurchaseHeader.Validate("PTSS Withholding Tax Code 2", WithholdingCode2);
                                PurchaseHeader.modify();
                                DiscountPercentage := 0;
                                UnitPrice := LibRandom.RandDecInDecimalRange(0.5, 500, 2);
                                quantity := Random(10);

                                purchaseLine.get(PurchaseHeader."Document Type", PurchaseHeader."No.", CreatePurchLineWithDifferentDiscountAndVATTax(PurchaseHeader, Enum::"Purchase Line Type"::Item, Item, quantity, Vendor, 23, DiscountPercentage, UnitPrice));
                                purchaseLine.Validate("PTSS Withholding Tax", true);
                                purchaseLine.Modify();

                                DocLineNumber -= 1;
                            until DocLineNumber = 0;
                        end;
                    4:
                        begin
                            DocLineNumber := Random(10);
                            repeat
                                PurchaseHeader.Validate("PTSS Withholding Tax Code 1", WithholdingCode1);
                                PurchaseHeader.Validate("PTSS Withholding Tax Code 2", WithholdingCode2);
                                PurchaseHeader.modify();
                                DiscountPercentage := LibRandom.RandDecInDecimalRange(1, 50, 2);
                                UnitPrice := LibRandom.RandDecInDecimalRange(0.5, 500, 2);
                                quantity := Random(10);

                                purchaseLine.get(PurchaseHeader."Document Type", PurchaseHeader."No.", CreatePurchLineWithDifferentDiscountAndVATTax(PurchaseHeader, Enum::"Purchase Line Type"::Item, Item, quantity, Vendor, 23, DiscountPercentage, UnitPrice));
                                purchaseLine.Validate("PTSS Withholding Tax", true);
                                purchaseLine.Modify();

                                DocLineNumber -= 1;
                            until DocLineNumber = 0;
                        end;
                end;

                purchaseLine.Reset();
                purchaseLine.SetRange(purchaseLine."PTSS Withholding Tax", true);
                if purchaseLine.FindSet() then begin
                    WithholdingTaxReturn.CreateWithholdingTaxPurchLine(PurchaseHeader);
                end;

                if IsIntegretion and (purchaseDocumentType = purchaseDocumentType::"return order") then begin
                    testerhelper.SetPurchaseDocForIntegratedSeries(PurchaseHeader, PurchaseDocumentType, NumberOfOrders, i, ReturnShipmentHeader);
                end else begin
                    if purchaseDocumentType <> purchaseDocumentType::"return order" then begin
                        error(NotReturnOrderError);
                    end;
                end;

                if IsRecovery and (purchaseDocumentType = purchaseDocumentType::"return order") then begin
                    testerhelper.SetPurchDocForRecoverySeries(PurchaseHeader, PurchaseDocumentType, NumberOfOrders, i);
                end else begin
                    if purchaseDocumentType <> purchaseDocumentType::"return order" then begin
                        error(NotReturnOrderError);
                    end;
                end;

                //if IsRecovery then begin
                //    TesterHelper.PostPurchRecovery(PurchaseHeader, purchaseDocumentType);
                //end else begin
                    PostPurchaseDocument(purchaseHeader, ToShipReceive, ToInvoice);
                //end;

                purchaseLine.Reset();
                i -= 1;
            until i = 0;
        end;
    end;

    procedure PostServiceOrder(var ServiceHeader: Record "Service Header")
    var
        ServiceOrderPage: TestPage "Service Order";
    begin
        ServiceOrderPage.OpenEdit();
        ServiceOrderPage.GoToRecord(ServiceHeader);
        ServiceOrderPage.Post.Invoke();
    end;

    procedure PostServiceQuote(var ServiceHeader: Record "Service Header")
    var
        ServiceQuotePage: TestPage "Service Quote";
    begin
        ServiceQuotePage.OpenEdit();
        ServiceQuotePage.GoToRecord(ServiceHeader);
        ServiceQuotePage."Make &Order".Invoke();
    end;

    procedure CreateServicelineWithDifferentDiscountAndVATTax(var ServiceHeader: Record "Service Header"; Type: Enum "service Line Type"; var Item: Record Item; Quantity: Decimal; var Customer: Record Customer; SAFTPTVATCode: Option; Discount: Decimal; UnitPrice: Decimal)
    var
        ServiceLine: Record "Service Line";
        VatPostSetup: Record "VAT Posting Setup";
        VatBusPostGroup: REcord "VAT Business Posting Group";
        VatProdPostGroup: REcord "VAT Product Posting Group";
        GLAccount: Record "G/L Account";
        GenPostSetup: Record "General Posting Setup";
    begin
        ServLib.CreateServiceLineWithQuantity(ServiceLine, ServiceHeader, ServiceLine.Type::Item, Item."No.", Quantity);

        VatProdPostGroup.get(Item."VAT Prod. Posting Group");
        VatBusPostGroup.get(Customer."VAT Bus. Posting Group");
        if SAFTPTVATCode in [1, 2, 3, 4, 5, 6] then begin
            CreateVATPostingSetupLineWithVatPercentageV2(VATPostSetup, VatProdPostGroup, VatBusPostGroup, SAFTPTVATCode);
        end else begin
            CreateVATPostingSetupLineWithVatPercentage(VATPostSetup, VatProdPostGroup, VatBusPostGroup, SAFTPTVATCode);
        end;

        genPostSetup.get(customer."Gen. Bus. Posting Group", item."Gen. Prod. Posting Group");
        ServiceHeader."Bill-to Customer No." := Customer."No.";
        ServiceHeader."VAT Bus. Posting Group" := VATPostSetup."VAT Bus. Posting Group";
        ServiceHeader."Gen. Bus. Posting Group" := genPostSetup."Gen. Bus. Posting Group";
        ServiceHeader.Modify();

        ServiceLine.Validate(Type, Type);
        ServiceLine.Validate("No.", Item."No.");
        ServiceLine.Validate("VAT Bus. Posting Group", VATPostSetup."VAT Bus. Posting Group");
        ServiceLine.Validate("VAT Prod. Posting Group", VATPostSetup."VAT Prod. Posting Group");
        ServiceLine.Validate("Gen. Bus. Posting Group", ServiceHeader."Gen. Bus. Posting Group");

        ServiceLine.Validate("VAT %", VATPostSetup."VAT %");
        if Quantity <> 0 then
            ServiceLine.Validate(Quantity, Quantity);
        if Item."Unit Price" = 0 then
            ServiceLine.Validate("Unit Price", UnitPrice);
        ServiceLine.Validate(Amount, Item."Unit Price");
        ServiceLine.Validate("Qty. to Invoice", Quantity);
        if (ServiceHeader."Document Type" = ServiceHeader."Document Type"::"Credit Memo") then begin
            ServiceLine.Validate("Qty. to Ship", 0);
            VATPostSetup.Validate("PTSS Return VAT Acc. (Sales)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
            VATPostSetup.Modify();
        end else begin
            ServiceLine.Validate("Qty. to Ship", Quantity);
        end;
        ServiceLine.Validate("Line Discount %", Discount);
        ServiceLine.Modify();
    end;

    procedure CreateServiceDocSimpleToCustomer(var ServiceHeader: Record "Service Header"; DocType: Enum "Service Document Type"; CustomerNo: Code[20])
    begin
        ServLib.CreateServiceHeader(ServiceHeader, DocType, CustomerNo);
        ServiceHeader.Validate("Due Date", Today);
        ServiceHeader.Modify();
    end;

    internal procedure CreateMultipleRandomServicesWithDiscount(NumberOfOrders: Integer; Customer: Record Customer; ServiceHeader: Record "Service Header"; ServiceDocumentType: Enum "Service Document Type"; CreateWDDocument: Boolean)
    var
        i: Integer;
        ServiceLine: Record "Service Line";
        DocLineNumber, DocCalculationType, VATRandom : Integer;
        Item: Record Item;
        DiscountPercentage, UnitPrice : Decimal;
        quantity: Integer;
    begin
        if NumberOfOrders > 1 then begin
            i := NumberOfOrders;
            CreateItemWithInventory(Item, 99999, Customer, false, 0, 4);

            repeat
                // DocCalculationType = 1 => Doc with no discount and no Withholding Tax, random VAT and random number of lines
                // DocCalculationType = 2 => Doc with discount, random VAT and random number of lines
                DocCalculationType := Random(2);

                case DocCalculationType of
                    1:
                        begin
                            DocLineNumber := Random(10);
                            CreateServiceDocSimpleToCustomer(ServiceHeader, ServiceDocumentType, Customer."No.");
                            repeat
                                DiscountPercentage := 0;
                                UnitPrice := LibRandom.RandDecInDecimalRange(0.5, 500, 2);
                                quantity := Random(10);
                                CreateServicelineWithDifferentDiscountAndVATTax(ServiceHeader, Enum::"Service Line Type"::Item, Item, quantity, Customer, 4, DiscountPercentage, UnitPrice);
                                DocLineNumber -= 1;
                            until DocLineNumber = 0;

                            if CreateWDDocument then begin
                                case ServiceHeader."Document Type" of
                                    ServiceHeader."Document Type"::Invoice:
                                        begin
                                            TesterHelper.PrintServiceInvoice(ServiceHeader);
                                        end;
                                    ServiceHeader."Document Type"::"Credit Memo":
                                        begin
                                            TesterHelper.PrintServiceCrMemo(ServiceHeader);
                                        end;
                                    ServiceHeader."Document Type"::Quote:
                                        begin
                                            TesterHelper.PrintServiceQuote(ServiceHeader);
                                        end;
                                    ServiceHeader."Document Type"::Order:
                                        begin
                                            TesterHelper.PrintServiceOrder(ServiceHeader);
                                        end;
                                end;
                            end;

                            case ServiceHeader."Document Type" of
                                ServiceHeader."Document Type"::Invoice:
                                    begin
                                        PostServiceDocument(ServiceHeader, true, true);
                                    end;
                                ServiceHeader."Document Type"::"Credit Memo":
                                    begin
                                        PostServiceDocument(ServiceHeader, true, true);
                                    end;
                                ServiceHeader."Document Type"::Quote:
                                    begin
                                        PostServiceDocument(ServiceHeader, true, true);
                                    end;
                                ServiceHeader."Document Type"::Order:
                                    begin
                                        PostServiceDocument(ServiceHeader, true, true);
                                    end;
                            end;
                            i -= 1;
                        end;
                    2:
                        begin
                            DocLineNumber := Random(10);
                            CreateServiceDocSimpleToCustomer(ServiceHeader, ServiceDocumentType, Customer."No.");
                            repeat
                                DiscountPercentage := LibRandom.RandDecInDecimalRange(1, 50, 2);
                                UnitPrice := LibRandom.RandDecInDecimalRange(0.5, 500, 2);
                                quantity := Random(10);
                                CreateServicelineWithDifferentDiscountAndVATTax(ServiceHeader, Enum::"Service Line Type"::Item, Item, quantity, Customer, 4, DiscountPercentage, UnitPrice);
                                DocLineNumber -= 1;
                            until DocLineNumber = 0;

                            if CreateWDDocument then begin
                                case ServiceHeader."Document Type" of
                                    ServiceHeader."Document Type"::Invoice:
                                        begin
                                            TesterHelper.PrintServiceInvoice(ServiceHeader);
                                        end;
                                    ServiceHeader."Document Type"::"Credit Memo":
                                        begin
                                            TesterHelper.PrintServiceCrMemo(ServiceHeader);
                                        end;
                                    ServiceHeader."Document Type"::Quote:
                                        begin
                                            TesterHelper.PrintServiceQuote(ServiceHeader);
                                        end;
                                    ServiceHeader."Document Type"::Order:
                                        begin
                                            TesterHelper.PrintServiceOrder(ServiceHeader);
                                        end;
                                end;
                            end;
                            case ServiceHeader."Document Type" of
                                ServiceHeader."Document Type"::Invoice:
                                    begin
                                        PostServiceDocument(ServiceHeader, true, true);
                                    end;
                                ServiceHeader."Document Type"::"Credit Memo":
                                    begin
                                        PostServiceDocument(ServiceHeader, true, true);
                                    end;
                                ServiceHeader."Document Type"::Quote:
                                    begin
                                        PostServiceDocument(ServiceHeader, true, true);
                                    end;
                                ServiceHeader."Document Type"::Order:
                                    begin
                                        PostServiceDocument(ServiceHeader, true, true);
                                    end;
                            end;
                            i -= 1;
                        end;
                end;
            until i = 0;
        end;
    end;

    procedure CreateSalesLineForCreditToMovNo(SalesHeader: Record "Sales Header"; Type: Enum "Sales Line Type"; var Item: Record Item; Quantity: Decimal; SAFTPTVATCode: Option; Discount: Decimal; UnitPrice: Decimal; GenJournalLine: Record "Gen. Journal Line")
    var
        SalesLine: Record "Sales Line";
        UnitofMeasure: Record "Unit of Measure";
        currency: Record Currency;
        Customer: Record Customer;
        CustLedgerEntry: Record "Cust. Ledger Entry";
        LineToCreditAUX: Integer;
    begin
        Customer.get(SalesHeader."Bill-to Customer No.");

        CreateSalesLineWithDifferentDiscountAndVATTax(SalesHeader, Enum::"Sales Line Type"::Item, Item, 15, Customer, SAFTPTVATCode, 0, 15);
        CustLedgerEntry.SetRange("Document No.", GenJournalLine."Document No.");
        CustLedgerEntry.FindSet();

        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.FindLast();
        SalesLine.Validate("PTSS Credit-to Mov. No.", CustLedgerEntry."Entry No.");
        SalesLine.Modify();
    end;

    procedure CreateGenJournalTemplate(var GenJournalTemplate: Record "Gen. Journal Template")
    var
        GenJournalTemplateCode: Text;
        GenJournalTemplateAUX: Record "Gen. Journal Template";
    begin
        GenJournalTemplateCode := LibUtil.GenerateRandomAlphabeticText(10, 1);
        if GenJournalTemplateAUX.get(GenJournalTemplateCode) then begin
            repeat
                GenJournalTemplateCode := LibUtil.GenerateRandomAlphabeticText(10, 1);

                GenJournalTemplateAUX.Reset();
            until not GenJournalTemplateAUX.get(GenJournalTemplateCode);
        end;

        GenJournalTemplate.Init();
        GenJournalTemplate.Validate(Name, GenJournalTemplateCode);
        GenJournalTemplate.Validate(Description, GenJournalTemplate.Name);
        // Validating Name as Description because value is not important.
        GenJournalTemplate.Insert(true);

        if not GenJournalTemplate."Force Doc. Balance" then begin
            GenJournalTemplate.Validate("Force Doc. Balance", true);  // This field is FALSE by default in ES. Setting this to TRUE to match ES with W1.
            GenJournalTemplate.Modify(true);
        end;
    end;

    procedure CreateGenProdPostingGroup(var GenProductPostingGroup: Record "Gen. Product Posting Group")
    var
        GenProductPostingGroupCode: Text;
        GenProductPostingGroupAUX: Record "Gen. Product Posting Group";
    begin
        GenProductPostingGroupCode := LibUtil.GenerateRandomAlphabeticText(10, 1);
        if GenProductPostingGroupAUX.get(GenProductPostingGroupCode) then begin
            repeat
                GenProductPostingGroupCode := LibUtil.GenerateRandomAlphabeticText(10, 1);

                GenProductPostingGroupAUX.Reset();
            until not GenProductPostingGroupAUX.get(GenProductPostingGroupCode);
        end;

        GenProductPostingGroup.Init();
        GenProductPostingGroup.Validate(Code, GenProductPostingGroupCode);
        // Validating Code as Name because value is not important.
        GenProductPostingGroup.Validate(Description, GenProductPostingGroupCode);
        GenProductPostingGroup.Insert(true);
    end;

    procedure CreateGenBusPostingGroup(var GenBusinessPostingGroup: Record "Gen. Business Posting Group")
    var
        GenBusinessPostingGroupCode: Text;
        GenBusinessPostingGroupAUX: Record "Gen. Business Posting Group";
    begin
        GenBusinessPostingGroupCode := LibUtil.GenerateRandomAlphabeticText(10, 1);
        if GenBusinessPostingGroupAUX.get(GenBusinessPostingGroupCode) then begin
            repeat
                GenBusinessPostingGroupCode := LibUtil.GenerateRandomAlphabeticText(10, 1);

                GenBusinessPostingGroupAUX.Reset();
            until not GenBusinessPostingGroupAUX.get(GenBusinessPostingGroupCode);
        end;

        GenBusinessPostingGroup.Init();
        GenBusinessPostingGroup.Validate(Code, GenBusinessPostingGroupCode);
        // Validating Code as Name because value is not important.
        GenBusinessPostingGroup.Validate(Description, GenBusinessPostingGroupCode);
        GenBusinessPostingGroup.Insert(true);
    end;

    procedure ReleasePurchaseDoc(var PurchaseHeader: Record "Purchase Header")
    var
        BatchProcessingMgt: Codeunit "Batch Processing Mgt.";
        NoOfSelected: Integer;
        NoOfSkipped: Integer;
    begin
        NoOfSelected := PurchaseHeader.Count;
        PurchaseHeader.SetFilter(Status, '<>%1', PurchaseHeader.Status::Released);
        NoOfSkipped := NoOfSelected - PurchaseHeader.Count;
        BatchProcessingMgt.BatchProcess(PurchaseHeader, Codeunit::"Purchase Manual Release", Enum::"Error Handling Options"::"Show Error", NoOfSelected, NoOfSkipped);
    end;

    procedure CalculateWithholdingPurch(var PurchaseHeader: Record "Purchase Header"; DocumentLine: text; vendor: Record vendor; WithholdingCode: Record "PTSS Withholding Tax Codes")
    var
        PurchaseLine: Record "Purchase Line";
        PurchaseDocLine: Integer;
        WithholdingTaxReturn: Codeunit "PTSS Withholding Tax Return";
        VATPostingSetup: Record "VAT Posting Setup";
        VATBusPostingGroup: Record "VAT Business Posting Group";
        VATProdPostingGroup: Record "VAT Product Posting Group";
        GLAccount: Record "G/L Account";
    begin
        Evaluate(PurchaseDocLine, DocumentLine + '0000');
        if (PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", PurchaseDocLine)) and (PurchaseLine.Type = PurchaseLine.Type::" ") then begin
            PurchaseLine.Next();
        end;

        GLAccount.get(WithholdingCode."G/L Account");
        if not VATPostingSetup.get(vendor."VAT Bus. Posting Group", GLAccount."VAT Prod. Posting Group") then begin
            VATBusPostingGroup.Get(vendor."VAT Bus. Posting Group");
            VATProdPostingGroup.Get(GLAccount."VAT Prod. Posting Group");
            CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProdPostingGroup, VATBusPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
        end;

        if PurchaseLine."PTSS Withholding Tax" then begin
            WithholdingTaxReturn.CreateWithholdingTaxPurchLine(PurchaseHeader);
        end;
    end;

    procedure CreateItemVendorVATProdANDWithInventory(var Item: Record Item; Qty: Decimal; var Vendor: Record Vendor; SAFTVATCode: Option; ItemPrice: Decimal)
    var
        ItemJnLine: Record "Item Journal Line";
        Template: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        InvPostSetup: Record "Inventory Posting Setup";
        InvPostGrp: Record "Inventory Posting Group";
        GLAcc: Record "G/L Account";
        VATPostSetup: Record "VAT Posting Setup";
        VATProdPostGrp: Record "VAT Product Posting Group";
        genPostSetup: Record "General Posting Setup";
        GenProdPostGrp: Record "Gen. Product Posting Group";
    begin
        LibInv.CreateItem(Item);

        case SAFTVATCode of
            1:
                begin
                    VATProdPostGrp.Get('EX_INT');
                end;
            2:
                begin
                    VATProdPostGrp.Get('EX_NR');
                end;
            3:
                begin
                    VATProdPostGrp.Get('EX_RD');
                end;
            4:
                begin
                    VATProdPostGrp.Get('EX_ISE');
                end;
            6:
                begin
                    VATProdPostGrp.Get('IMP_SELO');
                end;
        end;

        Item.Validate("Gen. Prod. Posting Group", 'MERC');
        Item.Validate("Item Category Code", 'MERC');
        Item.Validate("Inventory Posting Group", 'MERC');
        Item.validate("VAT Prod. Posting Group", VATProdPostGrp.code);
        Item.validate("Base Unit of Measure", 'UN');

        if not InvPostSetup.get('', 'MERC') then begin
            LibInv.CreateInventoryPostingSetup(InvPostSetup, '', 'MERC');
            TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            InvPostSetup."Inventory Account" := GLAcc."No.";
            InvPostSetup.Modify();
        end;

        if ItemPrice <> 0 then begin
            Item.Validate("Unit Price", ItemPrice);
        end;
        Item.Modify();

        GenProdPostGrp.get(item."Gen. Prod. Posting Group");

        CreateGeneralPostingSetupLineVendor(genPostSetup, GenProdPostGrp, VATPostSetup, VATProdPostGrp, Vendor);

        LibInv.CreateItemJournalTemplate(Template);
        LibInv.CreateItemJournalBatch(Batch, Template.Name);
        LibInv.CreateItemJournalLine(ItemJnLine, Template.Name, Batch.Name, ItemJnLine."Entry Type"::"Positive Adjmt.", Item."No.", Qty);
        ItemJnLine.Validate("Gen. Bus. Posting Group", genPostSetup."Gen. Bus. Posting Group");
        ItemJnLine.Validate("Inventory Posting Group", 'MERC');
        ItemJnLine.Modify(true);

        LibInv.PostItemJournalLine(ItemJnLine."Journal Template Name", ItemJnLine."Journal Batch Name");
    end;

    procedure CreateSalesLineForCreditToDocNo(SalesHeader: Record "Sales Header"; Type: Enum "Sales Line Type"; var Item: Record Item; Quantity: Decimal; SAFTPTVATCode: Option; Discount: Decimal; UnitPrice: Decimal; CreditToDocNo: Record "Sales Header"; LineToCredit: Text)
    var
        SalesLine: Record "Sales Line";
        SalesInvoiceLine: Record "Sales Invoice Line";
        UnitofMeasure: Record "Unit of Measure";
        currency: Record Currency;
        Customer: Record Customer;
        LineToCreditAUX: Integer;
    begin
        Customer.get(SalesHeader."Bill-to Customer No.");

        CreateSalesLineWithDifferentDiscountAndVATTax(SalesHeader, Enum::"Sales Line Type"::Item, Item, 15, Customer, SAFTPTVATCode, 0, 15);

        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.FindLast();
        SalesLine.Validate("PTSS Credit-to Doc. No.", CreditToDocNo."Last Posting No.");

        Evaluate(LineToCreditAUX, LineToCredit + '0000');

        SalesInvoiceLine.get(CreditToDocNo."Last Posting No.", LineToCreditAUX);
        SalesLine.Validate("PTSS Credit-to Doc. Line No.", SalesInvoiceLine."Line No.");
        SalesLine.Modify();
    end;

    procedure PostPrepaymentInvoiceSalesOrder(salesHeader: Record "Sales Header")
    var
        SalesOrderPage: TestPage "Sales Order";
    begin
        SalesOrderPage.OpenEdit();
        SalesOrderPage.GoToRecord(SalesHeader);
        SalesOrderPage.PostPrepaymentInvoice.Invoke();
    end;

    procedure CreateEndConsumerCustomerWithVATNo(var Customer: Record Customer)
    var
        Salesperson: Record "Salesperson/Purchaser";
        Contact: Record "Contact";
        ContactNo: Code[20];
    begin
        LibSales.CreateCustomer(Customer);
        Customer.Validate("PTSS End Consumer", true);
        TesterHelper.FillCustomerAddressFastTab(Customer);
        Customer.validate("Gen. Bus. Posting Group", 'NAC');
        Customer.Validate("VAT Bus. Posting Group", 'NACIONAL');
        Customer.validate("Customer Posting Group", 'NAC');
        Customer.validate("Payment Terms Code", '1MES');

        Customer.Modify();
    end;

    procedure SaveGenJournalLineAsSTDJournal(var GenJouLine: Record "Gen. Journal Line")
    var
        StandardGeneralJournal: Record "Standard General Journal";
        StandardGeneralJournalLine: Record "Standard General Journal Line";
        NextLineNo: Integer;
    begin
        StandardGeneralJournal.Init();
        StandardGeneralJournal.Validate("Journal Template Name", GenJouLine."Journal Template Name");
        StandardGeneralJournal.Validate(Code, LibUtil.GenerateRandomAlphabeticText(9, 1));
        StandardGeneralJournal.Validate(Description, StandardGeneralJournal.Code);
        StandardGeneralJournal.Insert(true);

        NextLineNo := 10000;
        repeat
            StandardGeneralJournalLine."Line No." := NextLineNo;
            NextLineNo := NextLineNo + 10000;
            StandardGeneralJournalLine.Init();
            StandardGeneralJournalLine.Validate("Journal Template Name", StandardGeneralJournal."Journal Template Name");
            StandardGeneralJournalLine.Validate("Standard Journal Code", StandardGeneralJournal.Code);
            StandardGeneralJournalLine.TransferFields(GenJouLine, false);
            StandardGeneralJournalLine.Validate("Shortcut Dimension 1 Code", '');
            StandardGeneralJournalLine.Validate("Shortcut Dimension 2 Code", '');
            StandardGeneralJournalLine.Insert(true);
        until GenJouLine.Next() = 0;
    end;

    procedure CreateBankAccount(var BankAccount: Record "Bank Account")
    var
        BankAccountPostingGroup: Record "Bank Account Posting Group";
        BankContUpdate: Codeunit "BankCont-Update";
        GLAcc: Record "G/L Account";
    begin
        LibERM.FindBankAccountPostingGroup(BankAccountPostingGroup);
        TesterHelper.CreateGLAccount(GLAcc, 1, Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
        BankAccountPostingGroup.Validate("G/L Account No.", GLAcc."No.");
        BankAccountPostingGroup.Modify();

        BankAccount.Init();
        BankAccount.Validate("No.", LibUtil.GenerateRandomCode(BankAccount.FieldNo("No."), DATABASE::"Bank Account"));
        BankAccount.Validate(Name, BankAccount."No.");  // Validating No. as Name because value is not important.
        BankAccount.Insert(true);
        BankAccount.Validate("Bank Acc. Posting Group", BankAccountPostingGroup.Code);
        BankAccount.Validate("Country/Region Code", 'PT');
        BankAccount.Modify(true);
        BankContUpdate.OnModify(BankAccount);
    end;

    procedure ReverseTransactionLedgerEntryCustomer(Customer: Record Customer; GenJouLine: Record "Gen. Journal Line")
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
        ReversalEntry: Record "Reversal Entry";
    begin
        CustLedgerEntry.SetRange("Customer No.", Customer."No.");
        CustLedgerEntry.SetRange("Document No.", GenJouLine."Document No.");
        if CustLedgerEntry.FindSet() then begin
            ReversalEntry.ReverseTransaction(CustLedgerEntry."Transaction No.");
        end else begin
            Error(LedgerEntryNotFind);
        end;
    end;

    procedure ReverseTransactionLedgerEntryVendor(Vendor: Record Vendor; GenJouLine: Record "Gen. Journal Line")
    var
        VendorLedgerEntry: Record "Vendor Ledger Entry";
        ReversalEntry: Record "Reversal Entry";
    begin
        VendorLedgerEntry.SetRange("Vendor No.", Vendor."No.");
        VendorLedgerEntry.SetRange("Document No.", GenJouLine."Document No.");
        if VendorLedgerEntry.FindSet() then begin
            ReversalEntry.ReverseTransaction(VendorLedgerEntry."Transaction No.");
        end else begin
            Error(LedgerEntryNotFind);
        end;
    end;

    internal procedure CreateCurrencyExchangeRate(var CurrencyExchangeRate: Record "Currency Exchange Rate"; var Currency: Record Currency)
    var
        ExchangeRateAmount: decimal;
    begin
        ExchangeRateAmount := LibRandom.RandDecInDecimalRange(0, 10, 2);

        CurrencyExchangeRate.Init();
        CurrencyExchangeRate.Validate("Starting Date", Today);
        CurrencyExchangeRate.Validate("Currency Code", Currency.Code);
        CurrencyExchangeRate.Validate("Exchange Rate Amount", ExchangeRateAmount);
        CurrencyExchangeRate.Validate("Relational Exch. Rate Amount", ExchangeRateAmount);
        CurrencyExchangeRate.Validate("Adjustment Exch. Rate Amount", ExchangeRateAmount);
        CurrencyExchangeRate.Validate("Relational Adjmt Exch Rate Amt", ExchangeRateAmount);
        CurrencyExchangeRate.insert();
    end;

    procedure CreateSalesDocSimpleBillToDefaultCustomer(var SalesHeader: Record "Sales Header"; DocType: Enum "Sales Document Type"; BillToOptions: Enum "Sales Bill-to Options"; CustomerNo: Code[20])
    begin
        if DocType = Enum::"Sales Document Type"::"PTSS Debit Memo" then begin
            DocType := Enum::"Sales Document Type"::Invoice;
            LibSales.CreateSalesHeader(SalesHeader, DocType, CustomerNo);
            SalesHeader.Validate("PTSS Debit Memo", true);
        end else begin
            LibSales.CreateSalesHeader(SalesHeader, DocType, CustomerNo);
        end;

        if BillToOptions = BillToOptions::"Default (Customer)" then begin
            SalesHeader.Validate("Bill-to Customer No.", SalesHeader."Sell-to Customer No.");
            SalesHeader.RecallModifyAddressNotification(SalesHeader.GetModifyBillToCustomerAddressNotificationId());
        end;

        SalesHeader.CopySellToAddressToBillToAddress();

        SalesHeader.Validate("Due Date", Today);
        SalesHeader.Modify();
    end;

    procedure CreatePurchLineWithDifferentDiscountAndVATTax(var PurchaseHeader: Record "Purchase Header"; Type: Enum "Purchase Line Type"; Item: Record Item;
                                                                                                                    Quantity: Decimal; var Vendor: Record Vendor; VATTaxPerc: Option; Discount: Decimal; UnitCost: Decimal): Integer
    var
        PurchaseLine: Record "Purchase Line";
        UnitofMeasure: REcord "Unit of Measure";
        VATProdPostGrp: Record "VAT Product Posting Group";
        VATBusPostGrp: REcord "VAT Business Posting Group";
        genPostSetup: Record "General Posting Setup";
        currency: Record Currency;
        VATPostSetup: Record "VAT Posting Setup";
        GenBusPostingGroup: record "Gen. Business Posting Group";
        GenProdPostingGroup: Record "Gen. Product Posting Group";
    begin
        VATProdPostGrp.get(Item."VAT Prod. Posting Group");
        VATBusPostGrp.get(vendor."VAT Bus. Posting Group");
        case VATTaxPerc of
            23:
                begin
                    CreateVATPostingSetupLineWithVatPercentage(VATPostSetup, VATProdPostGrp, VATBusPostGrp, VATPostSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate");
                end;
            13:
                begin
                    CreateVATPostingSetupLineWithVatPercentage(VATPostSetup, VATProdPostGrp, VATBusPostGrp, VATPostSetup."PTSS SAF-T PT VAT Code"::"Intermediate tax rate");
                end;
            6:
                begin
                    CreateVATPostingSetupLineWithVatPercentage(VATPostSetup, VATProdPostGrp, VATBusPostGrp, VATPostSetup."PTSS SAF-T PT VAT Code"::"Reduced tax rate");
                end;
            0:
                begin
                    CreateVATPostingSetupLineWithVatPercentage(VATPostSetup, VATProdPostGrp, VATBusPostGrp, VATPostSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                end;
        end;


        GenBusPostingGroup.get(vendor."Gen. Bus. Posting Group");
        GenProdPostingGroup.get(item."Gen. Prod. Posting Group");
        if not genPostSetup.get(GenBusPostingGroup.Code, GenProdPostingGroup.Code) then begin
            CreateGenPostSetupAndFillAccounts(GenBusPostingGroup, GenProdPostingGroup);
        end;
        genPostSetup.get(GenBusPostingGroup.Code, GenProdPostingGroup.Code);
        VATPostSetup.get(vendor."VAT Bus. Posting Group", Item."VAT Prod. Posting Group");

        LibPurch.CreatePurchaseLine(PurchaseLine, PurchaseHeader, Enum::"Purchase Line Type"::Item, Item."No.", Quantity);
        LibInv.CreateUnitOfMeasureCode(UnitofMeasure);

        PurchaseHeader."Pay-to Vendor No." := Vendor."No.";
        PurchaseHeader."VAT Bus. Posting Group" := VATPostSetup."VAT Bus. Posting Group";
        PurchaseHeader."Gen. Bus. Posting Group" := genPostSetup."Gen. Bus. Posting Group";
        PurchaseHeader.Modify();

        CreateEuroCurrency(currency);

        Item.Get(Item."No.");
        PurchaseLine.Validate(Type, Type);
        PurchaseLine.Validate("No.", Item."No.");
        PurchaseLine.Validate("Gen. Bus. Posting Group", PurchaseHeader."Gen. Bus. Posting Group");
        PurchaseLine.Validate("VAT Bus. Posting Group", VATPostSetup."VAT Bus. Posting Group");
        PurchaseLine.Validate("VAT Prod. Posting Group", VATPostSetup."VAT Prod. Posting Group");

        PurchaseLine.Validate("VAT %", VATPostSetup."VAT %");
        if Quantity <> 0 then
            PurchaseLine.Validate(Quantity, Quantity);
        PurchaseLine.Validate("Qty. to Invoice", Quantity);
        if Item."Unit Cost" = 0 then begin
            PurchaseLine.Validate("direct Unit Cost", UnitCost);
        end else begin
            PurchaseLine.Validate("direct Unit Cost", Item."Unit Cost");
        end;
        PurchaseLine.Validate("Line Discount %", Discount);
        PurchaseLine.Modify();

        exit(PurchaseLine."Line No.");
    end;

    procedure CreateItemCustomeVATProdANDWithInventory(var Item: Record Item; Qty: Decimal; var Customer: Record Customer; SAFTVATCode: Option; ItemPrice: Decimal)
    var
        ItemJnLine: Record "Item Journal Line";
        Template: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        InvPostSetup: Record "Inventory Posting Setup";
        InvPostGrp: Record "Inventory Posting Group";
        GLAcc: Record "G/L Account";
        VATPostSetup: Record "VAT Posting Setup";
        VATProdPostGrp: Record "VAT Product Posting Group";
        VATBusinessPostingGroup: Record "VAT Business Posting Group";
        genPostSetup: Record "General Posting Setup";
        GenProdPostGrp: Record "Gen. Product Posting Group";
        GenBusinessPostingGroup: Record "Gen. Business Posting Group";
        VATProdPostOption: Integer;
    begin
        LibInv.CreateItem(Item);
        VATProdPostOption := Random(4);

        case SAFTVATCode of
            1:
                begin
                    VATProdPostGrp.Get('EX_INT');
                end;
            2:
                begin
                    VATProdPostGrp.Get('EX_NR');
                end;
            3:
                begin
                    VATProdPostGrp.Get('EX_RD');
                end;
            4:
                begin
                    VATProdPostGrp.Get('EX_ISE');
                end;
            6:
                begin
                    VATProdPostGrp.Get('IMP_SELO');
                end;
        end;

        Item.Validate("Gen. Prod. Posting Group", 'MERC');
        Item.Validate("Item Category Code", 'MERC');
        Item.Validate("Inventory Posting Group", 'MERC');
        Item.validate("VAT Prod. Posting Group", VATProdPostGrp.code);
        Item.validate("Base Unit of Measure", 'UN');

        if not InvPostSetup.get('', 'MERC') then begin
            LibInv.CreateInventoryPostingSetup(InvPostSetup, '', 'MERC');
            TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            InvPostSetup."Inventory Account" := GLAcc."No.";
            InvPostSetup.Modify();
        end;

        if ItemPrice <> 0 then begin
            Item.Validate("Unit Price", ItemPrice);
        end;
        Item.Modify();

        GenProdPostGrp.get(item."Gen. Prod. Posting Group");

        CreateGeneralPostingSetupLine(genPostSetup, GenBusinessPostingGroup, GenProdPostGrp, VATPostSetup, VATProdPostGrp, VATBusinessPostingGroup, Customer);

        LibInv.CreateItemJournalTemplate(Template);
        LibInv.CreateItemJournalBatch(Batch, Template.Name);
        LibInv.CreateItemJournalLine(ItemJnLine, Template.Name, Batch.Name, ItemJnLine."Entry Type"::"Positive Adjmt.", Item."No.", Qty);
        ItemJnLine.Validate("Gen. Bus. Posting Group", genPostSetup."Gen. Bus. Posting Group");
        ItemJnLine.Validate("Inventory Posting Group", 'MERC');
        ItemJnLine.Modify(true);

        LibInv.PostItemJournalLine(ItemJnLine."Journal Template Name", ItemJnLine."Journal Batch Name");
    end;

    procedure CreateSalesLineWithDifferentDiscountAndVATTax(var SalesHeader: Record "Sales Header"; Type: Enum "Sales Line Type"; var Item: Record Item; Quantity: Decimal; var Customer: Record Customer; SAFTPTVATCode: Option; Discount: Decimal; UnitPrice: Decimal): Integer
    var
        SalesLine: Record "Sales Line";
        VATProdPostGrp: Record "VAT Product Posting Group";
        VATBusPostGrp: Record "VAT Business Posting Group";
        GenPostSetup: Record "General Posting Setup";
        VATPostSetup: Record "VAT Posting Setup";
        GLAccount: Record "G/L Account";
    begin
        LibSales.CreateSalesLineSimple(SalesLine, SalesHeader);

        VATProdPostGrp.get(Item."VAT Prod. Posting Group");
        VATBusPostGrp.get(Customer."VAT Bus. Posting Group");
        if SAFTPTVATCode in [1, 2, 3, 4, 5, 6] then begin
            CreateVATPostingSetupLineWithVatPercentageV2(VATPostSetup, VATProdPostGrp, VATBusPostGrp, SAFTPTVATCode);

        end else begin
            CreateVATPostingSetupLineWithVatPercentage(VATPostSetup, VATProdPostGrp, VATBusPostGrp, SAFTPTVATCode);
        end;

        genPostSetup.get(customer."Gen. Bus. Posting Group", item."Gen. Prod. Posting Group");
        SalesHeader."Bill-to Customer No." := Customer."No.";
        SalesHeader."VAT Bus. Posting Group" := VATPostSetup."VAT Bus. Posting Group";
        SalesHeader."Gen. Bus. Posting Group" := genPostSetup."Gen. Bus. Posting Group";
        SalesHeader.Modify();

        SalesLine.Validate(Type, Type);
        SalesLine.Validate("No.", Item."No.");
        salesline.Validate("Gen. Bus. Posting Group", SalesHeader."Gen. Bus. Posting Group");
        SalesLine.Validate("VAT Bus. Posting Group", VATPostSetup."VAT Bus. Posting Group");
        SalesLine.Validate("VAT Prod. Posting Group", VATPostSetup."VAT Prod. Posting Group");

        SalesLine.Validate("VAT %", VATPostSetup."VAT %");
        if Quantity <> 0 then
            SalesLine.Validate(Quantity, Quantity);
        if Item."Unit Price" = 0 then
            SalesLine.Validate("Unit Price", UnitPrice);
        SalesLine.Validate(Amount, Item."Unit Price");
        SalesLine.Validate("Qty. to Invoice", Quantity);
        if (SalesHeader."Document Type" = SalesHeader."Document Type"::"Credit Memo") or (SalesHeader."Document Type" = SalesHeader."Document Type"::"Return Order") then begin
            SalesLine.Validate("Qty. to Ship", 0);
            VATPostSetup.Validate("PTSS Return VAT Acc. (Sales)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
            VATPostSetup.Modify();
        end else begin
            SalesLine.Validate("Qty. to Ship", Quantity);
        end;
        SalesLine.Validate("Line Discount %", Discount);
        SalesLine.Modify();

        exit(SalesLine."Line No.");
    end;

    procedure CreateCountryRegion(var RegionCode: Record "Country/Region")
    var
        RegionCodeCode: Text;
    begin
        RegionCodeCode := 'I' + LibUtil.GenerateRandomAlphabeticText(7, 1);
        if not RegionCode.Get(RegionCodeCode) then begin
            RegionCode.Init();
            RegionCode.Validate(Code, RegionCodeCode);
            RegionCode.Insert(true);
        end;
    end;

    procedure CreatePaymentMethod(var PaymentMethod: Record "Payment Method")
    var
        PaymentMethodName: Text;
    begin
        PaymentMethodName := LibUtil.GenerateRandomAlphabeticText(8, 0);
        PaymentMethod.Init();
        PaymentMethod.Validate(Code, PaymentMethodName);
        PaymentMethod.Validate(Description, PaymentMethodName);
        PaymentMethod.Insert(true);
    end;

    procedure ReOpenSalesDoc(var SalesHeader: Record "Sales Header")
    var
        BatchProcessingMgt: Codeunit "Batch Processing Mgt.";
        NoOfSelected: Integer;
        NoOfSkipped: Integer;
    begin
        NoOfSelected := SalesHeader.Count;
        SalesHeader.SetFilter(Status, '<>%1', SalesHeader.Status::Open);
        NoOfSkipped := NoOfSelected - SalesHeader.Count;
        BatchProcessingMgt.BatchProcess(SalesHeader, Codeunit::"Sales Manual Reopen", Enum::"Error Handling Options"::"Show Error", NoOfSelected, NoOfSkipped);
    end;

    procedure ReleaseSalesDoc(var SalesHeader: Record "Sales Header")
    var
        BatchProcessingMgt: Codeunit "Batch Processing Mgt.";
        NoOfSelected: Integer;
        NoOfSkipped: Integer;
    begin
        NoOfSelected := SalesHeader.Count;
        SalesHeader.SetFilter(Status, '<>%1', SalesHeader.Status::Released);
        NoOfSkipped := NoOfSelected - SalesHeader.Count;
        BatchProcessingMgt.BatchProcess(SalesHeader, Codeunit::"Sales Manual Release", Enum::"Error Handling Options"::"Show Error", NoOfSelected, NoOfSkipped);
    end;

    procedure CreateAndPostTwoGenJourLinesWithSameBalAccAndDocNo(var GenJournalLine: Record "Gen. Journal Line"; BalAccType: Enum "Gen. Journal Account Type"; BalAccNo: Code[20]; DocNo: Code[20]): Code[20]
    var
        GenJournalTemplate: Record "Gen. Journal Template";
        GenJournalBatch: Record "Gen. Journal Batch";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesInvoiceLine: Record "Sales Invoice Line";
    begin
        SalesInvoiceHeader.get(DocNo);
        SalesInvoiceLine.get(SalesInvoiceHeader."No.", 10000);
        SalesInvoiceHeader.CalcFields("Amount Including VAT");

        CreateGenJournalTemplate(GenJournalTemplate);
        LibERM.CreateGenJournalBatch(GenJournalBatch, GenJournalTemplate.Name);
        LibERM.CreateGeneralJnlLineWithBalAcc(GenJournalLine, GenJournalTemplate.Name, GenJournalBatch.Name, GenJournalLine."Document Type"::Payment, GenJournalLine."Account Type"::Customer, SalesInvoiceHeader."Bill-to Customer No.", BalAccType, BalAccNo, -SalesInvoiceHeader."Amount Including VAT");
        GenJournalLine.Validate("Document No.", DocNo);
        GenJournalLine.Validate("Applies-to Doc. Type", GenJournalLine."Applies-to Doc. Type"::Invoice);
        GenJournalLine.Validate("Applies-to Doc. No.", SalesInvoiceHeader."No.");
        GenJournalLine.Validate("Bal. Gen. Bus. Posting Group", '');
        GenJournalLine.Validate("Bal. Gen. Prod. Posting Group", '');
        GenJournalLine.Validate("Bal. VAT Bus. Posting Group", '');
        GenJournalLine.Validate("Bal. VAT Prod. Posting Group", '');
        GenJournalLine.Modify(true);
        LibERM.PostGeneralJnlLine(GenJournalLine);

        exit(DocNo);
    end;

    procedure CreateAndPostGenJourLines(var GenJournalLine: Record "Gen. Journal Line"; DocTXT: Text; DocumentType: Enum "Gen. Journal Document Type"; AccountType: Enum "Gen. Journal Account Type"; AccountNo: Code[20]; BalAccType: Enum "Gen. Journal Account Type"; BalAccNo: Code[20]; Amount: Decimal; GenPostingType: Enum "General Posting Type"; PostGroup: Code[20]): Code[20]
    var
        GenJournalTemplate: Record "Gen. Journal Template";
        GenJournalBatch: Record "Gen. Journal Batch";
        SalesHeader: Record "Sales Header";
        DocCode: Code[20];
    begin
        CreateGenJournalTemplate(GenJournalTemplate);
        LibERM.CreateGenJournalBatch(GenJournalBatch, GenJournalTemplate.Name);
        LibERM.CreateGeneralJnlLineWithBalAcc(GenJournalLine, GenJournalTemplate.Name, GenJournalBatch.Name, DocumentType, AccountType, AccountNo, BalAccType, BalAccNo, Amount);

        case DocumentType of
            DocumentType::Payment:
                begin
                    DocTXT := 'GJ_PAY_0001';
                    SalesHeader.FindLast();
                    DocCode := SalesHeader."Last Posting No.";
                    GenJournalLine.Validate("Applies-to Doc. Type", DocumentType);
                    GenJournalLine.Validate("Applies-to Doc. No.", DocCode);
                end;
        end;

        GenJournalLine.Validate("Document No.", DocTXT);
        GenJournalLine.Validate("Bal. Gen. Bus. Posting Group", '');
        GenJournalLine.Validate("Bal. Gen. Prod. Posting Group", '');
        GenJournalLine.Validate("Bal. VAT Bus. Posting Group", '');
        GenJournalLine.Validate("Bal. VAT Prod. Posting Group", '');
        GenJournalLine.Validate("Gen. Bus. Posting Group", '');
        GenJournalLine.Validate("Gen. Prod. Posting Group", '');
        GenJournalLine.Validate("VAT Bus. Posting Group", '');
        GenJournalLine.Validate("VAT Prod. Posting Group", '');
        GenJournalLine.Validate("Gen. Posting Type", GenPostingType);
        if PostGroup <> ' ' then
            GenJournalLine.Validate("Posting Group", PostGroup);
        GenJournalLine.Modify(true);

        LibERM.PostGeneralJnlLine(GenJournalLine);

        exit(DocTXT);
    end;

    procedure CreateGenJournal(var GenJournalTemplate: Record "Gen. Journal Template"; var GenJournalBatch: Record "Gen. Journal Batch")
    begin
        if GenJournalTemplate.Name = '' then begin
            CreateGenJournalTemplate(GenJournalTemplate);
        end;
        if GenJournalBatch.Name = '' then begin
            LibERM.CreateGenJournalBatch(GenJournalBatch, GenJournalTemplate.Name);
        end;
    end;

    procedure CreateGenJournalLine(var GenJournalLine: Record "Gen. Journal Line"; GenJournalBatch: Record "Gen. Journal Batch"; GenJournalTemplate: Record "Gen. Journal Template"; DocNo: Text; DocumentType: Enum "Gen. Journal Document Type"; AccountType: Enum "Gen. Journal Account Type";
                                                                                                                                                                                                                     AccountNo: Code[20];
                                                                                                                                                                                                                     BalAccType: Enum "Gen. Journal Account Type";
                                                                                                                                                                                                                     BalAccNo: Code[20];
                                                                                                                                                                                                                     Amount: Decimal;
                                                                                                                                                                                                                     GenPostingType: Enum "General Posting Type"; BalGenPostingType: Enum "General Posting Type")
    var
        SalesHeader: Record "Sales Header";
        DocCode: Code[20];
        NoSeries: Record "No. Series";
        NoSeriesCodeunit: Codeunit "No. Series";
        RecRef: RecordRef;
    begin
        GenJournalBatch.Get(GenJournalTemplate.Name, GenJournalBatch.Name);

        GenJournalLine.Init();
        GenJournalLine.Validate("Journal Template Name", GenJournalTemplate.Name);
        GenJournalLine.Validate("Journal Batch Name", GenJournalBatch.Name);
        RecRef.GetTable(GenJournalLine);
        GenJournalLine.Validate("Line No.", LibUtil.GetNewLineNo(RecRef, GenJournalLine.FieldNo("Line No.")));
        GenJournalLine.Insert(true);
        GenJournalLine.Validate("Posting Date", WorkDate());
        GenJournalLine.Validate("VAT Reporting Date", WorkDate());
        GenJournalLine.Validate("Document Type", DocumentType);
        GenJournalLine.Validate("Account Type", AccountType);
        GenJournalLine.Validate("Account No.", AccountNo);
        GenJournalLine.Validate(Amount, Amount);
        if NoSeries.Get(GenJournalBatch."No. Series") then
            GenJournalLine.Validate("Document No.", NoSeriesCodeunit.PeekNextNo(GenJournalBatch."No. Series")) // Unused but required field for posting.
        else
            GenJournalLine.Validate(
              "Document No.", LibUtil.GenerateRandomCode(GenJournalLine.FieldNo("Document No."), DATABASE::"Gen. Journal Line"));
        GenJournalLine.Validate("External Document No.", GenJournalLine."Document No.");
        GenJournalLine.Validate("Source Code", LibERM.FindGeneralJournalSourceCode());
        GenJournalLine.Validate("Bal. Account Type", BalAccType);
        GenJournalLine.Validate("Bal. Account No.", BalAccNo);

        case DocumentType of
            DocumentType::Payment:
                begin
                    SalesHeader.FindLast();
                    DocCode := SalesHeader."Last Posting No.";
                    GenJournalLine.Validate("Applies-to Doc. Type", DocumentType);
                    GenJournalLine.Validate("Applies-to Doc. No.", DocCode);
                end;
        end;
        GenJournalLine.Validate("Gen. Posting Type", GenPostingType);
        GenJournalLine.Validate("Bal. Gen. Posting Type", BalGenPostingType);

        GenJournalLine.Modify(true);
    end;

    procedure PaymentRegistrationForCustomer(Customer: Record Customer; SalesHeader: Record "Sales Header")
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        GenJournalLine: Record "Gen. Journal Line";
        GLAccount: Record "G/L Account";
        RecRef: RecordRef;
    begin
        GenJournalLine.Init();
        GenJournalLine.Validate("Journal Template Name", 'PAG');
        GenJournalLine.Validate("Journal Batch Name", 'GENÉRICO');
        GenJournalLine.Validate("Line No.", 10000);
        RecRef.GetTable(GenJournalLine);
        GenJournalLine.Validate("Document Type", GenJournalLine."Document Type"::Payment);
        GenJournalLine.Validate("Document No.", 'PAY00001');
        GenJournalLine.Validate("Account Type", GenJournalLine."Account Type"::Customer);
        GenJournalLine.Validate("Account No.", Customer."No.");
        GenJournalLine.Validate(Description, SalesHeader."Last Posting No." + ' Payment');
        if SalesHeader."Document Type" = SalesHeader."Document Type"::Invoice then begin
            GenJournalLine.Validate("Applies-to Doc. Type", GenJournalLine."Applies-to Doc. Type"::Invoice);
        end;
        if SalesHeader."Document Type" = SalesHeader."Document Type"::"Credit Memo" then begin
            GenJournalLine.Validate("Applies-to Doc. Type", GenJournalLine."Applies-to Doc. Type"::"Credit Memo");
        end;
        GenJournalLine.Validate("Posting Date", SalesHeader."Posting Date");
        GenJournalLine.Validate("Applies-to Doc. No.", SalesHeader."Last Posting No.");
        GenJournalLine.Validate("Bal. Account No.", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));

        SalesHeader.CalcFields(Amount);
        LibERM.CreateAndPostTwoGenJourLinesWithSameBalAccAndDocNo(GenJournalLine, Enum::"Gen. Journal Account Type"::"G/L Account", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting), SalesHeader.Amount);
    end;

    procedure CreateCorretiveCrMemoSalesInvoice(var SalesHeader: Record "Sales Header")
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        CorrectPostedSalesInvoice: Codeunit "Correct Posted Sales Invoice";

        SalesLine: Record "Sales Line";
        SalesInvoiceLine: Record "Sales Invoice Line";
    begin
        SalesInvoiceHeader.get(SalesHeader."Last Posting No.");
        CorrectPostedSalesInvoice.CreateCreditMemoCopyDocument(SalesInvoiceHeader, SalesHeader);

        SalesLine.get(SalesHeader."Document Type", SalesHeader."No.", 20000);
        SalesInvoiceLine.get(SalesInvoiceHeader."No.", 10000);
    end;

    procedure CreateContactNo(var Contact: Record "Contact"; ContactType: Option)
    Var
        NoSeries: record "No. Series";
        MarketingSetup: record "Marketing Setup";
        NoSeriesManagement: Codeunit NoSeriesManagement;
    begin
        MarketingSetup.get();
        MarketingSetup.Validate("Contact Nos.", CreateNoSeries(false, false, false, NoSeries."PTSS SAF-T Invoice Type"::" "));
        MarketingSetup.modify();

        NoSeries.get(MarketingSetup."Contact Nos.");
        NoSeries.Validate("Manual Nos.", TRUE);
        NoSeries.modify();

        Contact.init();
        Contact.validate(Name, LibUtil.GenerateRandomAlphabeticText(10, 0));
        Contact.Validate(Type, ContactType);
        NoSeriesManagement.InitSeries(MarketingSetup."Contact Nos.", '', 0D, Contact."No.", Contact."No. Series");
        Contact.Validate("Phone No.", Format(random(999999999)));
        Contact.Insert();
    end;

    procedure CreateWithholdingCode(var WithholdingCode: Record "PTSS Withholding Tax Codes"; Is2WithholdingCodes: Boolean)
    var
        GLAccount: Record "G/L Account";
        IncomeTypeWT: Record "PTSS Income Type WT";
    begin
        TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + LibUtil.GenerateRandomNumericText(4), Enum::"G/L Account Type"::Posting);
        CreateIncomeTypeWT(IncomeTypeWT);
        WithholdingCode.Init();
        WithholdingCode.validate(Code, LibUtil.GenerateRandomCode(1, Database::"PTSS Withholding Tax Codes"));
        WithholdingCode.validate(Tax, Random(25));
        WithholdingCode.Validate("G/L Account", GLAccount."No.");
        WithholdingCode.Validate("Income Type", IncomeTypeWT.Code);
        WithholdingCode.Insert(true);

        if Is2WithholdingCodes then begin
            WithholdingCode.Init();
            WithholdingCode.validate(Code, LibUtil.GenerateRandomCode(1, Database::"PTSS Withholding Tax Codes"));
            WithholdingCode.validate(Tax, Random(25));
            WithholdingCode.Validate("G/L Account", GLAccount."No.");
            WithholdingCode.Validate("Income Type", IncomeTypeWT.Code);
            WithholdingCode.Insert(true);
        end;

    end;

    procedure CreateWithholdingCode(var WithholdingCode: Record "PTSS Withholding Tax Codes"; Is2WithholdingCodes: Boolean; FirstWithholdingCode: Decimal; SecondWithholdingCode: Decimal)
    var
        GLAccount: Record "G/L Account";
        IncomeTypeWT: Record "PTSS Income Type WT";
    begin
        if not (WithholdingCode.Get(Format(FirstWithholdingCode))) then begin
            TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting);
            CreateIncomeTypeWT(IncomeTypeWT);
            WithholdingCode.Init();
            WithholdingCode.validate(Code, Format(FirstWithholdingCode));
            WithholdingCode.validate(Tax, FirstWithholdingCode);
            WithholdingCode.Validate("G/L Account", GLAccount."No.");
            WithholdingCode.Validate("Income Type", IncomeTypeWT.Code);
            WithholdingCode.Insert(true);

            if not (WithholdingCode.Get(Format(SecondWithholdingCode))) then begin
                if Is2WithholdingCodes then begin
                    WithholdingCode.Init();
                    WithholdingCode.validate(Code, Format(SecondWithholdingCode));
                    WithholdingCode.validate(Tax, SecondWithholdingCode);
                    WithholdingCode.Validate("G/L Account", GLAccount."No.");
                    WithholdingCode.Validate("Income Type", IncomeTypeWT.Code);
                    WithholdingCode.Insert(true);
                end;
            end;
        end;
    end;

    procedure CreateIncomeTypeWT(var IncomeTypeWT: Record "PTSS Income Type WT")
    begin
        IncomeTypeWT.Init();
        IncomeTypeWT.Validate(code, LibUtil.GenerateRandomCode(1, Database::"PTSS Income Type WT"));
        IncomeTypeWT.Validate("Tax Description", IncomeTypeWT.code);
        IncomeTypeWT.Insert(true);
    end;

    procedure CalculateWithholding(SalesHeader: Record "Sales Header"; DocumentLine: text; Customer: Record Customer; WithholdingCode: Record "PTSS Withholding Tax Codes")
    var
        SalesLine: Record "Sales Line";
        SalesDocLine: Integer;
        WithholdingTaxReturn: Codeunit "PTSS Withholding Tax Return";
        VATPostingSetup: Record "VAT Posting Setup";
        VATBusPostingGroup: Record "VAT Business Posting Group";
        VATProdPostingGroup: Record "VAT Product Posting Group";
        GLAccount: Record "G/L Account";
    begin
        Evaluate(SalesDocLine, DocumentLine + '0000');
        if (SalesLine.Get(SalesHeader."Document Type", SalesHeader."No.", SalesDocLine)) and (SalesLine.Type = SalesLine.Type::" ") then begin
            SalesLine.Next();
        end;

        GLAccount.get(WithholdingCode."G/L Account");
        if not VATPostingSetup.get(Customer."VAT Bus. Posting Group", GLAccount."VAT Prod. Posting Group") then begin
            VATBusPostingGroup.Get(Customer."VAT Bus. Posting Group");
            VATProdPostingGroup.Get(GLAccount."VAT Prod. Posting Group");
            CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProdPostingGroup, VATBusPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
        end;

        if SalesLine."PTSS Withholding Tax" then begin
            WithholdingTaxReturn.CreateSalesWithholdingTax(SalesHeader);
        end;
    end;

    procedure CreateReminderTerms(var ReminderTerms: Record "Reminder Terms")
    begin
        ReminderTerms.init();
        ReminderTerms.validate(Code, LibUtil.GenerateRandomCode(1, 292));
        ReminderTerms.Validate("Post Additional Fee", true);
        ReminderTerms.validate("Max. No. of Reminders", 99999);
        ReminderTerms.Insert();
    end;

    procedure CreateVATBusinessSetupLine(var VATPostSetup: Record "VAT Posting Setup"; var VATProdPostGrp: Record "VAT Product Posting Group"; var Customer: Record Customer)
    var
        VATBusPostGrp: REcord "VAT Business Posting Group";
    begin
        LibERM.CreateVATBusinessPostingGroup(VATBusPostGrp);
    end;

    procedure CreateVATPostingSetupLineWithVatPercentage(var VATPostSetup: Record "VAT Posting Setup"; var VATProdPostGrp: Record "VAT Product Posting Group"; var VATBusPostGrp: REcord "VAT Business Posting Group"; SAFTPTVATCode: Option)
    var
        VATIdentifier: Code[20];
        VATPostSetupAUX: Record "VAT Posting Setup";
        GLAccount: Record "G/L Account";
    begin
        if (not VATPostSetup.get(VATBusPostGrp.Code, VATProdPostGrp.Code)) or (VATPostSetup."PTSS SAF-T PT VAT Code" = VATPostSetup."PTSS SAF-T PT VAT Code"::" ") or (VATPostSetup."PTSS SAF-T PT VAT Code" <> SAFTPTVATCode) then begin
            if not VATPostSetup.get(VATBusPostGrp.Code, VATProdPostGrp.Code) then begin
                LibERM.CreateVATPostingSetup(VATPostSetup, VATBusPostGrp.Code, VATProdPostGrp.Code);
            end;

            VATIdentifier := VATBusPostGrp.code + CopyStr(VATProdPostGrp.code, 1, StrLen(VATProdPostGrp.code));
            VATPostSetupAUX.SetRange("VAT Identifier", VATIdentifier);
            if VATPostSetupAUX.FindFirst() then begin
                repeat
                    VATIdentifier := LibUtil.GenerateRandomAlphabeticText(9, 1) + CopyStr(VATProdPostGrp.code, 1, StrLen(VATProdPostGrp.code));

                    VATPostSetupAUX.Reset();
                    VATPostSetupAUX.SetRange("VAT Identifier", VATIdentifier);
                until not VATPostSetupAUX.FindFirst();
            end;

            Case SAFTPTVATCode of
                VATPostSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate":
                    begin
                        VATPostSetup.validate("VAT Identifier", VATIdentifier);
                        VATPostSetup.Validate("PTSS SAF-T PT VAT Type Desc.", VATPostSetup."PTSS SAF-T PT VAT Type Desc."::"VAT Portugal Mainland");
                        VATPostSetup.Validate("VAT %", 23);
                        VATPostSetup.Validate("PTSS VAT D. %", 23);
                        VATPostSetup.Validate("PTSS SAF-T PT VAT Code", 2);
                        VATPostSetup.Validate("Sales VAT Account", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.VAlidate("Purchase VAT Account", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Purch.)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Sales)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                    end;
                VATPostSetup."PTSS SAF-T PT VAT Code"::"Intermediate tax rate":
                    begin
                        VATPostSetup.validate("VAT Identifier", VATIdentifier);
                        VATPostSetup.Validate("PTSS SAF-T PT VAT Type Desc.", VATPostSetup."PTSS SAF-T PT VAT Type Desc."::"VAT Portugal Mainland");
                        VATPostSetup.Validate("VAT %", 13);
                        VATPostSetup.Validate("PTSS VAT D. %", 13);
                        VATPostSetup.Validate("PTSS SAF-T PT VAT Code", 1);
                        VATPostSetup.Validate("Sales VAT Account", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.VAlidate("Purchase VAT Account", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Purch.)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Sales)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                    end;
                VATPostSetup."PTSS SAF-T PT VAT Code"::"Reduced tax rate":
                    begin
                        VATPostSetup.validate("VAT Identifier", VATIdentifier);
                        VATPostSetup.Validate("PTSS SAF-T PT VAT Type Desc.", VATPostSetup."PTSS SAF-T PT VAT Type Desc."::"VAT Portugal Mainland");
                        VATPostSetup.Validate("VAT %", 6);
                        VATPostSetup.Validate("PTSS VAT D. %", 6);
                        VATPostSetup.Validate("PTSS SAF-T PT VAT Code", 3);
                        VATPostSetup.Validate("Sales VAT Account", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.VAlidate("Purchase VAT Account", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Purch.)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Sales)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                    end;
                VATPostSetup."PTSS SAF-T PT VAT Code"::"No tax rate":
                    begin
                        VATPostSetup.Validate("VAT %", 0);
                        VATPostSetup.Validate("PTSS VAT D. %", 0);
                        VATPostSetup.Validate("PTSS SAF-T PT VAT Code", 4);
                        VATPostSetup.validate("VAT Clause Code", 'M99');
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Purch.)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Sales)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        if VATPostSetup."VAT Identifier" = '' then begin
                            VATPostSetup.validate("VAT Identifier", VATIdentifier);
                            VATPostSetup.Validate("PTSS SAF-T PT VAT Type Desc.", VATPostSetup."PTSS SAF-T PT VAT Type Desc."::"VAT Portugal Mainland");
                        end;
                    end;
                VATPostSetup."PTSS SAF-T PT VAT Code"::"Stamp Duty":
                    begin
                        VATPostSetup.Validate("VAT %", 0);
                        VATPostSetup.Validate("PTSS VAT D. %", 0);
                        VATPostSetup.Validate("PTSS SAF-T PT VAT Code", 6);
                        VATPostSetup.Validate("VAT Calculation Type", VATPostSetup."VAT Calculation Type"::"PTSS Stamp Duty");
                        VATPostSetup.validate("VAT Clause Code", 'M99');
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Purch.)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Sales)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        if VATPostSetup."VAT Identifier" = '' then begin
                            VATPostSetup.validate("VAT Identifier", VATIdentifier);
                            VATPostSetup.Validate("PTSS SAF-T PT VAT Type Desc.", VATPostSetup."PTSS SAF-T PT VAT Type Desc."::"VAT Portugal Mainland");
                        end;
                    end;
            End;
        end;
        VATPostSetup.modify();
    end;

    procedure CreateVATPostingSetupLineWithVatPercentageV2(var VATPostSetup: Record "VAT Posting Setup"; var VATProdPostGrp: Record "VAT Product Posting Group"; var VATBusPostGrp: REcord "VAT Business Posting Group"; SAFTPTVATCode: Option)
    var
        VATIdentifier: Code[20];
        VATPostSetupAUX: Record "VAT Posting Setup";
        GLAccount: Record "G/L Account";
    begin
        case SAFTPTVATCode of
            2:
                begin
                    VATProdPostGrp.Get('EX_NR');
                end;
            1:
                begin
                    VATProdPostGrp.Get('EX_INT');
                end;
            3:
                begin
                    VATProdPostGrp.Get('EX_RD');
                end;
            4:
                begin
                    VATProdPostGrp.Get('EX_ISE');
                end;
        end;

        if (not VATPostSetup.get(VATBusPostGrp.Code, VATProdPostGrp.Code)) or (VATPostSetup."PTSS SAF-T PT VAT Code" = VATPostSetup."PTSS SAF-T PT VAT Code"::" ") or (VATPostSetup."PTSS SAF-T PT VAT Code" <> SAFTPTVATCode) then begin
            if not VATPostSetup.get(VATBusPostGrp.Code, VATProdPostGrp.Code) then begin
                LibERM.CreateVATPostingSetup(VATPostSetup, VATBusPostGrp.Code, VATProdPostGrp.Code);
            end;

            VATIdentifier := VATBusPostGrp.code + CopyStr(VATProdPostGrp.code, 1, StrLen(VATProdPostGrp.code));
            VATPostSetupAUX.SetRange("VAT Identifier", VATIdentifier);
            if VATPostSetupAUX.FindFirst() then begin
                repeat
                    VATIdentifier := LibUtil.GenerateRandomAlphabeticText(9, 1) + CopyStr(VATProdPostGrp.code, 1, StrLen(VATProdPostGrp.code));

                    VATPostSetupAUX.Reset();
                    VATPostSetupAUX.SetRange("VAT Identifier", VATIdentifier);
                until not VATPostSetupAUX.FindFirst();
            end;

            Case SAFTPTVATCode of
                2:
                    begin
                        VATPostSetup.validate("VAT Identifier", VATIdentifier);
                        VATPostSetup.Validate("PTSS SAF-T PT VAT Type Desc.", VATPostSetup."PTSS SAF-T PT VAT Type Desc."::"VAT Portugal Mainland");
                        VATPostSetup.Validate("VAT %", 23);
                        VATPostSetup.Validate("PTSS VAT D. %", 23);
                        VATPostSetup.Validate("PTSS SAF-T PT VAT Code", 2);
                        VATPostSetup.Validate("Sales VAT Account", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.VAlidate("Purchase VAT Account", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Purch.)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Sales)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                    end;
                1:
                    begin
                        VATPostSetup.validate("VAT Identifier", VATIdentifier);
                        VATPostSetup.Validate("PTSS SAF-T PT VAT Type Desc.", VATPostSetup."PTSS SAF-T PT VAT Type Desc."::"VAT Portugal Mainland");
                        VATPostSetup.Validate("VAT %", 13);
                        VATPostSetup.Validate("PTSS VAT D. %", 13);
                        VATPostSetup.Validate("PTSS SAF-T PT VAT Code", 1);
                        VATPostSetup.Validate("Sales VAT Account", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.VAlidate("Purchase VAT Account", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Purch.)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Sales)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                    end;
                3:
                    begin
                        VATPostSetup.validate("VAT Identifier", VATIdentifier);
                        VATPostSetup.Validate("PTSS SAF-T PT VAT Type Desc.", VATPostSetup."PTSS SAF-T PT VAT Type Desc."::"VAT Portugal Mainland");
                        VATPostSetup.Validate("VAT %", 6);
                        VATPostSetup.Validate("PTSS VAT D. %", 6);
                        VATPostSetup.Validate("PTSS SAF-T PT VAT Code", 3);
                        VATPostSetup.Validate("Sales VAT Account", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.VAlidate("Purchase VAT Account", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Purch.)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Sales)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                    end;
                4:
                    begin
                        VATPostSetup.Validate("VAT %", 0);
                        VATPostSetup.Validate("PTSS VAT D. %", 0);
                        VATPostSetup.Validate("PTSS SAF-T PT VAT Code", 4);
                        VATPostSetup.validate("VAT Clause Code", 'M99');
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Purch.)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Sales)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        if VATPostSetup."VAT Identifier" = '' then begin
                            VATPostSetup.validate("VAT Identifier", VATIdentifier);
                            VATPostSetup.Validate("PTSS SAF-T PT VAT Type Desc.", VATPostSetup."PTSS SAF-T PT VAT Type Desc."::"VAT Portugal Mainland");
                        end;
                    end;
                5:
                    begin
                        VATPostSetup.Validate("VAT %", 0);
                        VATPostSetup.Validate("PTSS VAT D. %", 0);
                        VATPostSetup.Validate("PTSS SAF-T PT VAT Code", 6);
                        VATPostSetup.Validate("VAT Calculation Type", VATPostSetup."VAT Calculation Type"::"PTSS Stamp Duty");
                        VATPostSetup.validate("VAT Clause Code", 'M99');
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Purch.)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        VATPostSetup.Validate("PTSS Return VAT Acc. (Sales)", TesterHelper.CreateGLAccount(GLAccount, GLAccount."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999)), Enum::"G/L Account Type"::Posting));
                        if VATPostSetup."VAT Identifier" = '' then begin
                            VATPostSetup.validate("VAT Identifier", VATIdentifier);
                            VATPostSetup.Validate("PTSS SAF-T PT VAT Type Desc.", VATPostSetup."PTSS SAF-T PT VAT Type Desc."::"VAT Portugal Mainland");
                        end;
                    end;
            End;
        end;
        VATPostSetup.modify();
    end;

    procedure CreateGeneralPostingSetupLine(var GenPostSetup: Record "General Posting Setup"; var GenBusPostGrp: Record "Gen. Business Posting Group"; var GenProdPostGrp: Record "Gen. Product Posting Group"; var VATPostingSetup: Record "VAT Posting Setup"; var VATProductPostingGroup: Record "VAT Product Posting Group"; var VATBusinessPostingGroup: Record "VAT Business Posting Group"; var Customer: Record Customer)
    var
        GLAcc: Record "G/L Account";
    begin
        if GenBusPostGrp.code = '' then begin
            CreateGenBusPostingGroup(GenBusPostGrp);
        end;
        if GenProdPostGrp.code = '' then begin
            CreateGenProdPostingGroup(GenProdPostGrp);
        end;
        if not GenPostSetup.get(GenBusPostGrp.Code, GenProdPostGrp.Code) then begin
            LibERM.CreateGeneralPostingSetup(GenPostSetup, GenBusPostGrp.Code, GenProdPostGrp.Code);
        end;

        if VATBusinessPostingGroup.code = '' then begin
            LibERM.CreateVATBusinessPostingGroup(VATBusinessPostingGroup);
        end;
        if VATProductPostingGroup.code = '' then begin
            LibERM.CreateVATProductPostingGroup(VATProductPostingGroup);
        end;

        GenPostSetup.validate("Sales Account", TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999999)), Enum::"G/L Account Type"::Posting));
        GenPostSetup.Validate("Sales Prepayments Account", TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999999)), Enum::"G/L Account Type"::Posting));
        GLAcc.Validate("VAT Prod. Posting Group", VATProductPostingGroup.Code);
        GLAcc.Modify();
        GenPostSetup.validate("Sales Credit Memo Account", TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999999)), Enum::"G/L Account Type"::Posting));
        GenPostSetup.validate("Purch. Account", TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999999)), Enum::"G/L Account Type"::Posting));
        GenPostSetup.validate("COGS Account", TesterHelper.CreateGLAccount(GLAcc, GLAcc."Income/Balance"::"Balance Sheet", Format(LibRandom.RandIntInRange(2, 8)) + Format(Random(9999999)), Enum::"G/L Account Type"::Posting));

        if not VATPostingSetup.get(VATBusinessPostingGroup.code, VATProductPostingGroup.code) then begin
            //LibERM.CreateVATPostingSetup(VATPostingSetup, VATBusinessPostingGroup.code, VATProductPostingGroup.code);
            case VATProductPostingGroup.Code of
                'EX_NR':
                    begin
                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProductPostingGroup, VATBusinessPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate");
                    end;
                'EX_INT':
                    begin
                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProductPostingGroup, VATBusinessPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Intermediate tax rate");
                    end;
                'EX_RD':
                    begin
                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProductPostingGroup, VATBusinessPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Reduced tax rate");
                    end;
                'EX_ISE':
                    begin
                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProductPostingGroup, VATBusinessPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                    end;
            end;
        end;

        Customer.validate("Gen. Bus. Posting Group", GenBusPostGrp.Code);
        Customer.validate("VAT Bus. Posting Group", VATBusinessPostingGroup.code);
        GenPostSetup.modify(true);
        Customer.Modify(true);
    end;

    procedure ChangePurchasesPayablesSetupNoSeries(NoSeries: Record "No. Series"; DocType: Text)
    var
        PurchasesPayablesSetup: Record "Purchases & Payables Setup";
    begin
        PurchasesPayablesSetup.get();

        Case DocType of
            'Return Shipment No.':
                PurchasesPayablesSetup.Validate("Posted Return Shpt. Nos.", NoSeries.Code);
        End;
    end;

    internal procedure CreateMultipleRandomSalesWithDiscountNWithholdingNPost(NumberOfOrders: Integer; SalesHeader: Record "Sales Header"; SalesDocumentType: Enum "Sales Document Type";
                                                                                                                                                                  No: Code[20];
                                                                                                                                                                  ship: Boolean;
                                                                                                                                                                  invoice: Boolean;
                                                                                                                                                                  newCustPostGroup: Boolean;
                                                                                                                                                                  sizeofCPG: Integer;
                                                                                                                                                                  DirectDebit: Boolean; IsPrepayment: Boolean; IsIntegretion: Boolean; IsRecovery: Boolean)
    var
        i: Integer;
        Item: Record Item;
        CustPostGroup: Record "Customer Posting Group";
        Customer: REcord Customer;
        SalesLine: Record "Sales Line";
        WithholdingCode: Record "PTSS Withholding Tax Codes";
        DocLineNumber, DocCalculationType : Integer;
        WithholdingCode1, WithholdingCode2 : Decimal;
        WithholdingTaxReturn: Codeunit "PTSS Withholding Tax Return";
        VATPostingSetup: Record "VAT Posting Setup";
        VATBusPostingGroup: Record "VAT Business Posting Group";
        VATProdPostingGroup: Record "VAT Product Posting Group";
        PrepaymentPercentage, DiscountPercentage, UnitPrice : Decimal;
        GLAccount: Record "G/L Account";
        IsDebit: Boolean;
        PrepaymentDueDate, PrepmtPmtDiscountDate : Date;
        quantity: Integer;
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
        SalesHeader1: Record "Sales Header";
        SalesInvoiceHeader: Record "Sales Invoice Header";
    begin
        SalesReceivablesSetup.get();
        if newCustPostGroup then begin
            Customer.Get(No);
            CreateCustomerPostingSetupAndAssignToCustomer(CustPostGroup, Customer, sizeofCPG);
        end else begin
            Customer.Get(No);
        end;

        if SalesDocumentType = SalesDocumentType::"PTSS Debit Memo" then begin
            IsDebit := true;
            SalesDocumentType := SalesDocumentType::Invoice;
        end;

        CreateItemWithInventory(Item, 999999, Customer, false, 0, Random(4));

        if IsIntegretion or IsRecovery then begin
            CreateSalesDocSimpleBillToDefaultCustomer(SalesHeader1, Enum::"Sales Document Type"::Invoice, Enum::"Sales Bill-to Options"::"Default (Customer)", Customer."No.");
            CreateSalesLineWithDifferentDiscountAndVATTax(SalesHeader1, Enum::"Sales Line Type"::Item, Item, 1, Customer, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate", 0, 1);
            PostSalesDocument(SalesHeader1, ship, invoice);
            SalesInvoiceHeader.get(SalesHeader1."Last Posting No.");
        end;

        if NumberOfOrders > 1 then begin
            i := NumberOfOrders;
            repeat
                // DocCalculationType = 1 => Doc with no discount and no Withholding Tax, random VAT and random number of lines
                // DocCalculationType = 2 => Doc with discount and no Withholding Tax, random VAT and random number of lines
                // DocCalculationType = 3 => Doc no discount and with Withholding Tax, random VAT and random number of lines
                // DocCalculationType = 4 => Doc with discount and with Withholding Tax, random VAT and random number of lines

                PrepaymentPercentage := LibRandom.RandDecInDecimalRange(1, 40, 2);

                CreateSalesDocSimpleBillToDefaultCustomer(SalesHeader, SalesDocumentType, Enum::"Sales Bill-to Options"::"Default (Customer)", Customer."No.");
                if (IsPrepayment) and (SalesHeader."Document Type" = SalesHeader."Document Type"::Order) then begin
                    TesterHelper.SalesHeaderPrepaymentInformation(SalesHeader, PrepaymentPercentage, PrepaymentDueDate, 0, PrepmtPmtDiscountDate, '', true);
                    DocCalculationType := Random(2);
                end else begin
                    DocCalculationType := Random(4);
                end;

                case DocCalculationType of
                    1:
                        begin
                            DocLineNumber := Random(10);
                            repeat
                                UnitPrice := LibRandom.RandDecInDecimalRange(0.5, 500, 2);
                                quantity := Random(10);
                                CreateSalesLineWithDifferentDiscountAndVATTax(SalesHeader, Enum::"Sales Line Type"::Item, Item, quantity, Customer, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate", 0, UnitPrice);

                                DocLineNumber -= 1;
                            until DocLineNumber = 0;
                        end;
                    2:
                        begin
                            DocLineNumber := Random(10);
                            repeat
                                DiscountPercentage := LibRandom.RandDecInDecimalRange(1, 50, 2);
                                UnitPrice := LibRandom.RandDecInDecimalRange(0.5, 500, 2);
                                quantity := Random(10);
                                CreateSalesLineWithDifferentDiscountAndVATTax(SalesHeader, Enum::"Sales Line Type"::Item, Item, quantity, Customer, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate", DiscountPercentage, UnitPrice);
                                DocLineNumber -= 1;
                            until DocLineNumber = 0;
                        end;
                    3:
                        begin
                            DocLineNumber := Random(10);
                            repeat
                                WithholdingCode1 := LibRandom.RandDecInDecimalRange(1, 40, 2);
                                WithholdingCode2 := LibRandom.RandDecInDecimalRange(1, 40, 2);
                                UnitPrice := LibRandom.RandDecInDecimalRange(0.5, 500, 2);
                                quantity := Random(10);
                                SalesLine.get(SalesHeader."Document Type", SalesHeader."No.", CreateSalesLineWithDifferentDiscountAndVATTax(SalesHeader, Enum::"Sales Line Type"::Item, Item, quantity, Customer, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate", 0, UnitPrice));
                                TesterHelper.AddDiscountAndWithholdingTaxToTheSalesLine(SalesHeader, SalesLine, SalesLine."Line No.", 0, true, WithholdingCode1, WithholdingCode2);

                                if WithholdingCode1 <> 0 then begin
                                    WithholdingCode.Get(SalesHeader."PTSS Withholding Tax Code");
                                    GLAccount.get(WithholdingCode."G/L Account");
                                    if not VATPostingSetup.get(Customer."VAT Bus. Posting Group", GLAccount."VAT Prod. Posting Group") then begin
                                        VATBusPostingGroup.Get(Customer."VAT Bus. Posting Group");
                                        VATProdPostingGroup.Get(GLAccount."VAT Prod. Posting Group");
                                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProdPostingGroup, VATBusPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                                    end;
                                    WithholdingCode.Reset();
                                end;
                                if WithholdingCode2 <> 0 then begin
                                    WithholdingCode.Get(SalesHeader."PTSS Withholding Tax Code 2");
                                    GLAccount.get(WithholdingCode."G/L Account");
                                    if not VATPostingSetup.get(Customer."VAT Bus. Posting Group", GLAccount."VAT Prod. Posting Group") then begin
                                        VATBusPostingGroup.Get(Customer."VAT Bus. Posting Group");
                                        VATProdPostingGroup.Get(GLAccount."VAT Prod. Posting Group");
                                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProdPostingGroup, VATBusPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                                    end;
                                    WithholdingCode.Reset();
                                end;
                                DocLineNumber -= 1;
                            until DocLineNumber = 0;
                        end;
                    4:
                        begin
                            DocLineNumber := Random(10);
                            repeat
                                WithholdingCode1 := LibRandom.RandDecInDecimalRange(1, 40, 2);
                                WithholdingCode2 := LibRandom.RandDecInDecimalRange(1, 40, 2);
                                DiscountPercentage := LibRandom.RandDecInDecimalRange(1, 50, 2);
                                UnitPrice := LibRandom.RandDecInDecimalRange(0.5, 500, 2);
                                quantity := Random(10);
                                SalesLine.get(SalesHeader."Document Type", SalesHeader."No.", CreateSalesLineWithDifferentDiscountAndVATTax(SalesHeader, Enum::"Sales Line Type"::Item, Item, quantity, Customer, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate", DiscountPercentage, UnitPrice));
                                TesterHelper.AddDiscountAndWithholdingTaxToTheSalesLine(SalesHeader, SalesLine, SalesLine."Line No.", DiscountPercentage, true, WithholdingCode1, WithholdingCode2);
                                if WithholdingCode1 <> 0 then begin
                                    WithholdingCode.Get(SalesHeader."PTSS Withholding Tax Code");
                                    GLAccount.get(WithholdingCode."G/L Account");
                                    if not VATPostingSetup.get(Customer."VAT Bus. Posting Group", GLAccount."VAT Prod. Posting Group") then begin
                                        VATBusPostingGroup.Get(Customer."VAT Bus. Posting Group");
                                        VATProdPostingGroup.Get(GLAccount."VAT Prod. Posting Group");
                                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProdPostingGroup, VATBusPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                                    end;
                                    WithholdingCode.Reset();
                                end;
                                if WithholdingCode2 <> 0 then begin
                                    WithholdingCode.Get(SalesHeader."PTSS Withholding Tax Code 2");
                                    GLAccount.get(WithholdingCode."G/L Account");
                                    if not VATPostingSetup.get(Customer."VAT Bus. Posting Group", GLAccount."VAT Prod. Posting Group") then begin
                                        VATBusPostingGroup.Get(Customer."VAT Bus. Posting Group");
                                        VATProdPostingGroup.Get(GLAccount."VAT Prod. Posting Group");
                                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProdPostingGroup, VATBusPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                                    end;
                                    WithholdingCode.Reset();
                                end;

                                DocLineNumber -= 1;
                            until DocLineNumber = 0;
                        end;
                end;

                SalesLine.Reset();
                SalesLine.SetRange(SalesLine."PTSS Withholding Tax", true);
                if SalesLine.FindSet() then begin
                    WithholdingTaxReturn.CreateSalesWithholdingTax(SalesHeader);
                end;

                if IsIntegretion then begin
                    TesterHelper.SetSalesDocForIntegratedSeries(SalesHeader, SalesDocumentType, NumberOfOrders, i, SalesInvoiceHeader);
                end;

                if IsRecovery then begin
                    TesterHelper.SetSalesDocForRecoverySeries(SalesHeader, SalesDocumentType, NumberOfOrders, i, SalesInvoiceHeader);
                end;

                if IsDebit then begin
                    PostSalesDebitMemo(SalesHeader);
                end else begin
                    if (IsPrepayment) and (SalesHeader."Document Type" = SalesHeader."Document Type"::Order) then begin
                        PostPrepaymentInvoiceSalesOrder(SalesHeader);
                        PostPrepaymentCrMemoSalesOrder(SalesHeader);
                        SalesHeader.DeleteAll();
                    end else begin
                        if IsRecovery then begin
                            TesterHelper.PostSalesRecovery(SalesHeader, SalesDocumentType);
                        end else begin
                            PostSalesDocument(SalesHeader, ship, invoice);
                        end;
                    end;
                end;
                i -= 1;
            until i = 0;
        end;
    end;

    internal procedure CreateMultipleRandomWorkingDocumentsWithDiscountNWithholdingNPost(NumberOfOrders: Integer; SalesHeader: Record "Sales Header"; SalesDocumentType: Enum "Sales Document Type";
                                                                                                                                                                             No: Code[20];
                                                                                                                                                                             ship: Boolean;
                                                                                                                                                                             invoice: Boolean;
                                                                                                                                                                             newCustPostGroup: Boolean;
                                                                                                                                                                             sizeofCPG: Integer;
                                                                                                                                                                             DirectDebit: Boolean;
                                                                                                                                                                             IsWDProForma: Boolean)
    var
        i: Integer;
        Item: Record Item;
        CustPostGroup: Record "Customer Posting Group";
        Customer: REcord Customer;
        SalesLine: Record "Sales Line";
        WithholdingCode: Record "PTSS Withholding Tax Codes";
        DocLineNumber, DocCalculationType, GLAccountAux1, GLAccountAux2 : Integer;
        WithholdingCode1, WithholdingCode2 : Decimal;
        WithholdingTaxReturn: Codeunit "PTSS Withholding Tax Return";
        VATPostingSetup: Record "VAT Posting Setup";
        VATBusPostingGroup: Record "VAT Business Posting Group";
        VATProdPostingGroup: Record "VAT Product Posting Group";
        GLAccount: Record "G/L Account";
        WithholdingTaxCodes: Record "PTSS Withholding Tax Codes";
        IsDebit: Boolean;
        DiscountPercentage, UnitPrice : Decimal;
        quantity: Integer;
    begin
        if newCustPostGroup then begin
            Customer.Get(No);
            CreateCustomerPostingSetupAndAssignToCustomer(CustPostGroup, Customer, sizeofCPG);
        end else begin
            Customer.Get(No);
        end;

        if NumberOfOrders > 1 then begin
            i := NumberOfOrders;
            repeat
                // DocCalculationType = 1 => Doc with no discount and no Withholding Tax, random VAT and random number of lines
                // DocCalculationType = 2 => Doc with discount and no Withholding Tax, random VAT and random number of lines
                // DocCalculationType = 3 => Doc no discount and with Withholding Tax, random VAT and random number of lines
                // DocCalculationType = 4 => Doc with discount and with Withholding Tax, random VAT and random number of lines

                DocCalculationType := Random(4);

                CreateSalesDocSimpleBillToDefaultCustomer(SalesHeader, SalesDocumentType, Enum::"Sales Bill-to Options"::"Default (Customer)", Customer."No.");
                AddSellToContactNoToDocumentHeader(SalesHeader, Customer);
                CreateItemWithInventory(Item, 999999, Customer, false, 0, Random(4));

                case DocCalculationType of
                    1:
                        begin
                            DocLineNumber := Random(10);
                            repeat
                                DiscountPercentage := 0;
                                UnitPrice := LibRandom.RandDecInDecimalRange(0.5, 500, 2);
                                quantity := Random(10);

                                CreateSalesLineWithDifferentDiscountAndVATTax(SalesHeader, Enum::"Sales Line Type"::Item, Item, quantity, Customer, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate", DiscountPercentage, UnitPrice);
                                DocLineNumber -= 1;
                            until DocLineNumber = 0;

                            If SalesDocumentType = SalesDocumentType::"Blanket Order" then begin
                                SalesDocumentType := SalesDocumentType::Order;
                            end;

                            case SalesDocumentType of
                                SalesDocumentType::Quote:
                                    begin
                                        TesterHelper.PrintSalesQuote(SalesHeader);
                                    end;
                                SalesDocumentType::Order:
                                    begin
                                        if IsWDProForma then begin
                                            TesterHelper.PrintProforma(SalesHeader);
                                        end else begin
                                            TesterHelper.PrintSalesOrder(SalesHeader);
                                        end;
                                    end;
                                SalesDocumentType::Invoice:
                                    begin
                                        if IsWDProForma then begin
                                            TesterHelper.PrintProforma(SalesHeader);
                                        end;
                                    end;
                            end;
                            i -= 1;

                            //TODO Em processo de Fix
                            if SalesHeader."Document Type" <> SalesHeader."Document Type"::"Blanket Order" then begin
                                SalesHeader.Delete(true);
                            end;
                        end;
                    2:
                        begin
                            DocLineNumber := Random(10);
                            repeat
                                DiscountPercentage := LibRandom.RandDecInDecimalRange(1, 50, 2);
                                UnitPrice := LibRandom.RandDecInDecimalRange(0.5, 500, 2);
                                quantity := Random(10);

                                CreateSalesLineWithDifferentDiscountAndVATTax(SalesHeader, Enum::"Sales Line Type"::Item, Item, quantity, Customer, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate", DiscountPercentage, UnitPrice);
                                DocLineNumber -= 1;
                            until DocLineNumber = 0;

                            If SalesDocumentType = SalesDocumentType::"Blanket Order" then begin
                                SalesDocumentType := SalesDocumentType::Order;
                            end;

                            case SalesDocumentType of
                                SalesDocumentType::Quote:
                                    begin
                                        TesterHelper.PrintSalesQuote(SalesHeader);
                                    end;
                                SalesDocumentType::Order:
                                    begin
                                        if IsWDProForma then begin
                                            TesterHelper.PrintProforma(SalesHeader);
                                        end else begin
                                            TesterHelper.PrintSalesOrder(SalesHeader);
                                        end;
                                    end;
                                SalesDocumentType::Invoice:
                                    begin
                                        if IsWDProForma then begin
                                            TesterHelper.PrintProforma(SalesHeader);
                                        end;
                                    end;
                            end;
                            i -= 1;

                            //TODO Em processo de Fix
                            if SalesHeader."Document Type" <> SalesHeader."Document Type"::"Blanket Order" then begin
                                SalesHeader.Delete(true);
                            end;
                        end;
                    3:
                        begin
                            DocLineNumber := Random(10);
                            repeat
                                WithholdingCode1 := Random(50);
                                WithholdingCode2 := Random(50);
                                Customer.get(SalesHeader."Sell-to Customer No.");
                                DiscountPercentage := 0;
                                UnitPrice := LibRandom.RandDecInDecimalRange(0.5, 500, 2);
                                quantity := Random(10);

                                SalesLine.get(SalesHeader."Document Type", SalesHeader."No.", CreateSalesLineWithDifferentDiscountAndVATTax(SalesHeader, Enum::"Sales Line Type"::Item, Item, quantity, Customer, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate", DiscountPercentage, UnitPrice));

                                CreateWithholdingCode(WithholdingTaxCodes, true, WithholdingCode1, WithholdingCode2);
                                if WithholdingCode.Get(WithholdingCode1) then begin
                                    Evaluate(GLAccountAux1, WithholdingCode."G/L Account");
                                    GLAccount.get(GLAccountAux1);
                                    if not VATPostingSetup.get(Customer."VAT Bus. Posting Group", GLAccount."VAT Prod. Posting Group") then begin
                                        VATBusPostingGroup.Get(Customer."VAT Bus. Posting Group");
                                        VATProdPostingGroup.Get(GLAccount."VAT Prod. Posting Group");

                                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProdPostingGroup, VATBusPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                                    end;
                                    WithholdingCode.Reset();
                                    GLAccount.Reset();
                                    VATProdPostingGroup.Reset();
                                    VATBusPostingGroup.Reset();
                                    VATPostingSetup.Reset();
                                end;
                                if WithholdingCode.Get(WithholdingCode2) then begin
                                    Evaluate(GLAccountAux2, WithholdingCode."G/L Account");
                                    GLAccount.get(GLAccountAux2);
                                    if not VATPostingSetup.get(Customer."VAT Bus. Posting Group", GLAccount."VAT Prod. Posting Group") then begin
                                        VATBusPostingGroup.Get(Customer."VAT Bus. Posting Group");
                                        VATProdPostingGroup.Get(GLAccount."VAT Prod. Posting Group");

                                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProdPostingGroup, VATBusPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                                    end;
                                    WithholdingCode.Reset();
                                    GLAccount.Reset();
                                    VATProdPostingGroup.Reset();
                                    VATBusPostingGroup.Reset();
                                    VATPostingSetup.Reset();
                                end;

                                TesterHelper.AddDiscountAndWithholdingTaxToTheSalesLine(SalesHeader, SalesLine, SalesLine."Line No.", DiscountPercentage, true, WithholdingCode1, WithholdingCode2);

                                DocLineNumber -= 1;
                            until DocLineNumber = 0;

                            SalesLine.Reset();
                            SalesLine.SetRange(SalesLine."PTSS Withholding Tax", true);
                            if SalesLine.FindSet() then begin
                                WithholdingTaxReturn.CreateSalesWithholdingTax(SalesHeader);
                            end;

                            If SalesDocumentType = SalesDocumentType::"Blanket Order" then begin
                                SalesDocumentType := SalesDocumentType::Order;
                            end;

                            case SalesDocumentType of
                                SalesDocumentType::Quote:
                                    begin
                                        TesterHelper.PrintSalesQuote(SalesHeader);
                                    end;
                                SalesDocumentType::Order:
                                    begin
                                        if IsWDProForma then begin
                                            TesterHelper.PrintProforma(SalesHeader);
                                        end else begin
                                            TesterHelper.PrintSalesOrder(SalesHeader);
                                        end;
                                    end;
                                SalesDocumentType::Invoice:
                                    begin
                                        if IsWDProForma then begin
                                            TesterHelper.PrintProforma(SalesHeader);
                                        end;
                                    end;
                            end;
                            i -= 1;

                            //TODO Em processo de Fix
                            if SalesHeader."Document Type" <> SalesHeader."Document Type"::"Blanket Order" then begin
                                SalesHeader.Delete(true);
                            end;
                        end;
                    4:
                        begin
                            DocLineNumber := Random(10);
                            repeat
                                WithholdingCode1 := Random(50);
                                WithholdingCode2 := Random(50);
                                DiscountPercentage := LibRandom.RandDecInDecimalRange(1, 50, 2);
                                UnitPrice := LibRandom.RandDecInDecimalRange(0.5, 500, 2);
                                quantity := Random(10);

                                SalesLine.get(SalesHeader."Document Type", SalesHeader."No.", CreateSalesLineWithDifferentDiscountAndVATTax(SalesHeader, Enum::"Sales Line Type"::Item, Item, quantity, Customer, VATPostingSetup."PTSS SAF-T PT VAT Code"::"Normal tax rate", DiscountPercentage, UnitPrice));

                                CreateWithholdingCode(WithholdingTaxCodes, true, WithholdingCode1, WithholdingCode2);
                                if WithholdingCode.Get(WithholdingCode1) then begin
                                    Evaluate(GLAccountAux1, WithholdingCode."G/L Account");
                                    GLAccount.get(GLAccountAux1);
                                    if not VATPostingSetup.get(Customer."VAT Bus. Posting Group", GLAccount."VAT Prod. Posting Group") then begin
                                        VATBusPostingGroup.Get(Customer."VAT Bus. Posting Group");
                                        VATProdPostingGroup.Get(GLAccount."VAT Prod. Posting Group");

                                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProdPostingGroup, VATBusPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                                    end;
                                    WithholdingCode.Reset();
                                    GLAccount.Reset();
                                    VATProdPostingGroup.Reset();
                                    VATBusPostingGroup.Reset();
                                    VATPostingSetup.Reset();
                                end;
                                if WithholdingCode.Get(WithholdingCode2) then begin
                                    Evaluate(GLAccountAux2, WithholdingCode."G/L Account");
                                    GLAccount.get(GLAccountAux2);
                                    if not VATPostingSetup.get(Customer."VAT Bus. Posting Group", GLAccount."VAT Prod. Posting Group") then begin
                                        VATBusPostingGroup.Get(Customer."VAT Bus. Posting Group");
                                        VATProdPostingGroup.Get(GLAccount."VAT Prod. Posting Group");

                                        CreateVATPostingSetupLineWithVatPercentage(VATPostingSetup, VATProdPostingGroup, VATBusPostingGroup, VATPostingSetup."PTSS SAF-T PT VAT Code"::"No tax rate");
                                    end;
                                    WithholdingCode.Reset();
                                    GLAccount.Reset();
                                    VATProdPostingGroup.Reset();
                                    VATBusPostingGroup.Reset();
                                    VATPostingSetup.Reset();
                                end;

                                TesterHelper.AddDiscountAndWithholdingTaxToTheSalesLine(SalesHeader, SalesLine, SalesLine."Line No.", DiscountPercentage, true, WithholdingCode1, WithholdingCode2);

                                DocLineNumber -= 1;
                            until DocLineNumber = 0;

                            SalesLine.Reset();
                            SalesLine.SetRange(SalesLine."PTSS Withholding Tax", true);
                            if SalesLine.FindSet() then begin
                                WithholdingTaxReturn.CreateSalesWithholdingTax(SalesHeader);
                            end;

                            If SalesDocumentType = SalesDocumentType::"Blanket Order" then begin
                                SalesDocumentType := SalesDocumentType::Order;
                            end;

                            case SalesDocumentType of
                                SalesDocumentType::Quote:
                                    begin
                                        TesterHelper.PrintSalesQuote(SalesHeader);
                                    end;
                                SalesDocumentType::Order:
                                    begin
                                        if IsWDProForma then begin
                                            TesterHelper.PrintProforma(SalesHeader);
                                        end else begin
                                            TesterHelper.PrintSalesOrder(SalesHeader);
                                        end;
                                    end;
                                SalesDocumentType::Invoice:
                                    begin
                                        if IsWDProForma then begin
                                            TesterHelper.PrintProforma(SalesHeader);
                                        end;
                                    end;
                            end;
                            i -= 1;

                            //TODO Em processo de Fix
                            if SalesHeader."Document Type" <> SalesHeader."Document Type"::"Blanket Order" then begin
                                SalesHeader.Delete(true);
                            end;
                        end;
                end;
            until i = 0;
        end;
    end;

    internal procedure CreateMultipleSalesLines(NumberOfOrders: Integer; SalesHeader: Record "Sales Header"; SalesDocumentType: Enum "Sales Document Type"; Item: Record Item;
                                                                                                                                    quantity: Integer;
                                                                                                                                    No: Code[20];
                                                                                                                                    ship: Boolean;
                                                                                                                                    invoice: Boolean;
                                                                                                                                    newCustPostGroup: Boolean;
                                                                                                                                    sizeofCPG: Integer;
                                                                                                                                    DirectDebit: Boolean;
                                                                                                                                    CreateVatSetup: Boolean)
    var
        i: Integer;
        CustPostGroup: Record "Customer Posting Group";
        Customer: REcord Customer;
        SalesRec: Record "Sales & Receivables Setup";
    begin
        if newCustPostGroup then begin
            Customer.Get(No);
            CreateCustomerPostingSetupAndAssignToCustomer(CustPostGroup, Customer, sizeofCPG);
        end;


        if NumberOfOrders > 1 then begin
            i := NumberOfOrders;
            repeat
                CreateSalesDocForNonExistingItems(SalesHeader, SalesDocumentType, Item, quantity, No, DirectDebit, CreateVatSetup);
                PostSalesDebitMemo(SalesHeader);
                i -= 1;

            until i = 0;
            exit;
        end else begin
            CreateSalesDocForNonExistingItems(SalesHeader, SalesDocumentType, Item, quantity, No, DirectDebit, CreateVatSetup);
            PostSalesDebitMemo(SalesHeader);
        end;
    end;

    internal procedure CreateMultipleWorkingDocumentsAndPrint(NumberOfOrders: Integer; SalesHeader: Record "Sales Header"; SalesDocumentType: Enum "Sales Document Type"; Item: Record Item;
                                                                                                                                                  quantity: Integer;
                                                                                                                                                  No: Code[20];
                                                                                                                                                  ship: Boolean;
                                                                                                                                                  invoice: Boolean;
                                                                                                                                                  newCustPostGroup: Boolean;
                                                                                                                                                  sizeofCPG: Integer;
                                                                                                                                                  DirectDebit: Boolean;
                                                                                                                                                  CreateVatSetup: Boolean;
                                                                                                                                                  IsWDProForma: Boolean)
    var
        i: Integer;
        CustPostGroup: Record "Customer Posting Group";
        Customer: Record Customer;
        Contact: Record "Contact";

        SalesLine: Record "Sales Line";
    begin
        if newCustPostGroup then begin
            CreateCustomerPostingSetupAndAssignToCustomer(CustPostGroup, Customer, sizeofCPG);
        end;

        if NumberOfOrders > 1 then begin
            i := NumberOfOrders;
            repeat
                CreateSalesDocForNonExistingItems(SalesHeader, SalesDocumentType, Item, quantity, No, DirectDebit, CreateVatSetup);
                Customer.get(SalesHeader."Sell-to Customer No.");
                AddSellToContactNoToDocumentHeader(SalesHeader, Customer);
                CreateSalesLineWithShipmentDate(SalesLine, SalesHeader, Enum::"Sales Line Type"::Item, Item, SalesHeader."Shipment Date", quantity, false, Customer, CreateVatSetup);

                case SalesDocumentType of
                    SalesDocumentType::Quote:
                        begin
                            TesterHelper.PrintSalesQuote(SalesHeader);
                        end;
                    SalesDocumentType::Order:
                        begin
                            if IsWDProForma then begin
                                TesterHelper.PrintProforma(SalesHeader);
                            end else begin
                                TesterHelper.PrintSalesOrder(SalesHeader);
                            end;
                        end;
                end;

                //TesterHelper.DeleteSalesDoc(SalesHeader);
                SalesHeader.Delete();
                i -= 1;

            until i = 0;
        end else begin
            CreateSalesDocForNonExistingItems(SalesHeader, SalesDocumentType, Item, quantity, No, DirectDebit, CreateVatSetup);
            if SalesDocumentType = SalesDocumentType::Quote then begin
                TesterHelper.PrintSalesQuote(SalesHeader);
            end;
        end;
    end;

    procedure ToggleInventorySetup(LocationMandatory: Boolean; PreventNegativeInventory: Boolean; AllowInventoryAdjustment: Boolean)
    var
        InventorySetup: Record "Inventory Setup";
    begin
        InventorySetup.get();
        InventorySetup.Validate("Location Mandatory", LocationMandatory);
        InventorySetup.validate("Prevent Negative Inventory", PreventNegativeInventory);
        InventorySetup.validate("Allow Inventory Adjustment", AllowInventoryAdjustment);
        InventorySetup.modify();
    end;

    procedure CreateNoSeriesV2(var NoSeries: Record "No. Series"; var NoSeriesLine: Record "No. Series Line"; SAFT: Boolean; GTAT: Boolean; WD: Boolean; RC: Boolean; DocType: Option): Code[20]
    var
        NoSeriesText: Text;
        Error: Label 'SAFT and GTAT cannot be both true';
        RecRef: RecordRef;
    begin
        NoSeriesText := LibUtil.GenerateRandomCode(1, 308);
        LibUtil.CreateNoSeries(NoSeries, true, false, false);
        if SAFT then
            NoSeries.Validate("PTSS SAF-T Invoice Type", DocType);
        if GTAT then
            NoSeries.Validate("PTSS GTAT Document Type", DocType);
        if WD then
            NoSeries.Validate("PTSS SAF-T Working Doc Type", DocType);
        if RC then
            NoSeries.validate("PTSS Receipt Type", DocType);

        //LibUtil.CreateNoSeriesLine(NoSeriesLine, NoSeries.Code, NoSeriesText + '0001', NoSeriesText + '9999');  

        NoSeriesLine.Init();

        NoSeriesLine."Starting Date" := Today;
        NoSeriesLine.Validate("Series Code", NoSeries.Code);
        RecRef.GetTable(NoSeriesLine);
        NoSeriesLine.Validate("Line No.", LibUtil.GetNewLineNo(RecRef, NoSeriesLine.FieldNo("Line No.")));


        if (NoSeriesText + '0001') = '' then
            NoSeriesLine.Validate("Starting No.", PadStr(InsStr(NoSeries.Code, '0000', 3), 10))
        else
            NoSeriesLine.Validate("Starting No.", NoSeriesText + '0001');
        //NoSeriesLine.Validate("Starting No.", NoSeriesText + '0002');

        if (NoSeriesText + '9999') = '' then
            NoSeriesLine.Validate("Ending No.", PadStr(InsStr(NoSeries.Code, '9999', 3), 10))
        else
            NoSeriesLine.Validate("Ending No.", NoSeriesText + '9999');

        NoSeriesLine.validate("PTSS SAF-T No. Series Del.", StrLen(NoSeriesText));
        NoSeriesLine.Validate("PTSS AT Validation Code", LibUtil.GenerateRandomAlphabeticText(9, 0));
        NoSeriesLine.Insert();
        //NoSeriesLine.Modify();
        //exit(NoSeries.Code);
    end;

    procedure CreatePurchaseDocSimpleForVendorNo(var PurchaseHeader: Record "Purchase Header"; DocType: Enum "Purchase Document Type"; VendorNo: Code[20])
    begin
        LibPurch.CreatePurchHeader(PurchaseHeader, DocType, VendorNo);
        PurchaseHeader.Validate("Due Date", Today);
        if DocType = DocType::"return order" then begin
            PurchaseHeader.Validate("Vendor Cr. Memo No.", LibUtil.GenerateRandomAlphabeticText(9, 1));
        end;
        PurchaseHeader.Modify();
    end;

    procedure CreateNoSeriesWithoutLines(var NoSeries: Record "No. Series"; SAFT: Boolean; GTAT: Boolean; WD: Boolean; RC: Boolean)
    begin
        LibUtil.CreateNoSeries(NoSeries, true, false, false);
        // if SAFT and GTAT then
        //     Error(Error);
        if SAFT then
            NoSeries.Validate("PTSS SAF-T Invoice Type", NoSeries."PTSS SAF-T Invoice Type"::FR);
        if GTAT then
            NoSeries.Validate("PTSS GTAT Document Type", NoSeries."PTSS GTAT Document Type"::GA);
        if WD then
            NoSeries.Validate("PTSS SAF-T Working Doc Type", NoSeries."PTSS SAF-T Working Doc Type"::NE);
        if RC then
            NoSeries.validate("PTSS Receipt Type", NoSeries."PTSS Receipt Type"::"PTSS Cash VAT Receipt");
    end;

    #endregion

    #region globalvars
    var
        LibRandom: Codeunit "Library - Random";
        LibSales: Codeunit "Library - Sales";
        TesterHelper: Codeunit "PTSS Tester Helper";
        LibERM: Codeunit "Library - ERM";
        LibInv: Codeunit "Library - Inventory";
        Libassembly: Codeunit "Library - Assembly";
        LibUtil: Codeunit "Library - Utility";
        ServLib: Codeunit "Library - Service";
        WareHouseLib: Codeunit "Library - Warehouse";
        LibPurch: Codeunit "Library - Purchase";
        Assert: Codeunit "Library Assert";
        SSVerify: Codeunit "PTSS Verify Tests";
        WrongDocumentTypeErr: Label 'Document type not supported: %1';
        LedgerEntryNotFind: Label 'Ledger Entry Not Find';

    #endregion
}