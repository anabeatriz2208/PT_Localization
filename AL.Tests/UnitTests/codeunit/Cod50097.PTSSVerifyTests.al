codeunit 50097 "PTSS Verify Tests"
{
    #region jrosa

    procedure PostedSalesInvoiceHasHash(SalesHeader: Record "Sales Header")
    var
        PostedSalesInvoice: Record "Sales Invoice Header";
    begin

        // The Customer Was Just Created, so It will Only Have 1 associated Posted Sales Invoice
        PostedSalesInvoice.SetFilter("Bill-to Customer No.", SalesHeader."Bill-to Customer No.");

        if PostedSalesInvoice.FindFirst then
            PostedSalesInvoice.TestField("PTSS Hash")
        else
            Error(NotFoundErr);
    end;

    procedure PostedSalesCreditMemoHasHash(SalesHeader: Record "Sales Header")
    var
        PostedSalesCreditMemo: Record "Sales Cr.Memo Header";
    begin
        PostedSalesCreditMemo.SetFilter("Bill-to Customer No.", SalesHeader."Bill-to Customer No.");

        if PostedSalesCreditMemo.FindFirst then
            PostedSalesCreditMemo.TestField("PTSS Hash")
        else
            Error(NotFoundErr);
    end;

    procedure PostedServiceInvoiceHasHash(ServiceHeader: Record "Service Header")
    var
        PostedServInvoice: Record "Service Invoice Header";
    begin
        PostedServInvoice.SetFilter("Bill-to Customer No.", ServiceHeader."Customer No.");

        if PostedServInvoice.FindFirst() then
            PostedServInvoice.TestField("PTSS Hash")
        else
            Error(NotFoundErr);
    end;

    procedure PostedServiceCreditMemoHasHash(ServiceHeader: Record "Service Header")
    var
        PostedServCreditMemo: Record "Service Cr.Memo Header";
    begin
        PostedServCreditMemo.SetFilter("Bill-to Customer No.", ServiceHeader."Customer No.");

        if PostedServCreditMemo.FindFirst() then
            PostedServCreditMemo.TestField("PTSS Hash")
        else
            Error(NotFoundErr);
    end;

    procedure FinChargeMemoHasHash(FinChargeMemo: Record "Finance Charge Memo Header")
    var
        IssuedFinChargeMemo: Record "Issued Fin. Charge Memo Header";
        e: Integer;
    begin
        IssuedFinChargeMemo.FindSet();

        if IssuedFinChargeMemo.FindFirst then
            IssuedFinChargeMemo.TestField("PTSS Hash")
        else
            Error(NotFoundErr);
    end;

    internal procedure "Check If MovsGL Values Are correct"(Count: Integer; ToPay: Decimal; VATDeduct: Decimal; VATND: Decimal; TotalCost: Decimal; Account_D: code[30]; Account_ND: code[30])
    var
        ErrorCount: Label 'Record has wrong entries';
        InconcistentError: Label 'Inconcistent sum. Check Movs G/L';
        WrongSignal: Label 'Number has wrong signal';
        Chart: Record "G/L Account";
        ErrorWrongAccount: Label 'Error Wrong Account';
    begin
        if ToPay < 0 then ToPay := -Topay;
        if TotalCost > 0 then TotalCost := -TotalCost;
        // [THEN] Amount to Pay should be > 0
        Assert.IsTrue(ToPay > 0, WrongSignal);
        // [THEN] VAT Deduct value should be > 0
        Assert.IsTrue(VATDeduct >= 0, WrongSignal);
        // [THEN] VAT ND value should be = 0
        Assert.IsTrue(VATND <= 0, WrongSignal);
        // [THEN] TotalCost should be < 0
        Assert.IsTrue(TotalCost < 0, WrongSignal);
        // [THEN] Total Sum should be 0
        Assert.AreEqual(0, ToPay + VATDeduct + VATND + TotalCost, InconcistentError);
        // [THEN] Value of VATDeduct should be on correct G/L Account
        // if not (Account_D = '') then begin
        //     Chart.SetRange("No.", Account_D);
        //     Chart.FindFirst();
        //     Assert.AreEqual('IVA A RECEBER', Chart.Name, ErrorWrongAccount);
        // end;
        // // [THEN] Value of VATDeduct should be on correct G/L Account
        // if not (Account_ND = '') then begin
        //     Chart.SetRange("No.", Account_ND);
        //     Chart.FindFirst();
        //     Assert.AreEqual('IVA A PAGAR', Chart.Name, ErrorWrongAccount);
        // end;
    end;

    procedure ReminderHasHash(ReminderHeader: Record "Reminder Header")
    var
        IssuedReminder: Record "Issued Reminder Header";
    begin
        //IssuedReminder.FindSet();
        //IssuedReminder.SetRange("Customer No.", ReminderHeader."Customer No.");

        if IssuedReminder.FindFirst then
            IssuedReminder.TestField("PTSS Hash")
        else
            Error(NotFoundErr);
    end;

    procedure ServShipRepHasHash()
    var
        ServShipmentHeader: Record "Service Shipment Header";
    begin
        if ServShipmentHeader.FindLast() then
            ServShipmentHeader.TestField("PTSS Hash")
        else
            Error(NotFoundErr);
    end;

    procedure PostedTransferOrderHasHash()
    var
        TransferShpmHeader: Record "Transfer Shipment Header";
    begin
        if TransferShpmHeader.FindLast() then
            TransferShpmHeader.TestField("PTSS Hash")
        else
            Error(NotFoundErr);
    end;

    procedure SalesShipRepHasHash()
    var
        SalesShipmentHeader: Record "Sales Shipment Header";
    begin
        if SalesShipmentHeader.FindLast then
            SalesShipmentHeader.TestField("PTSS Hash")
        else
            Error(NotFoundErr);
    end;

    procedure PostedReturnOrderHasHash(PurchHeader: Record "Purchase Header")
    var
        PostedReturnOrder: Record "Return Shipment Header";
    begin
        PostedReturnOrder.SetRange("Return Order No.", PurchHeader."No.");
        PostedReturnOrder.SetFilter("Sell-to Customer No.", PurchHeader."Sell-to Customer No.");

        if PostedReturnOrder.FindLast() then
            PostedReturnOrder.TestField("PTSS Hash")
        else
            Error(NotFoundErr);
    end;

    procedure ErrorTextEqualsTo(ExpectedError: Text)
    var
        ErrText: Text;
    begin
        ErrText := System.GetLastErrorText();
        Assert.AreEqual(ExpectedError, ErrText, UnexpectedErr);
    end;

    procedure ErrorTextContains(ExpectedError: Text)
    var
        ErrText: Text;
    begin
        ErrText := System.GetLastErrorText();
        Assert.AreEqual(true, ErrText.Contains(ExpectedError), UnexpectedErr);
    end;

    procedure CreditToFieldsWereAutomaticallyFilled(var SalesCrMemo: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetFilter("Document Type", Format(SalesCrMemo."Document Type"));
        SalesLine.SetFilter("Document No.", SalesCrMemo."No.");
        SalesLine.SetFilter(Type, Format(Enum::"Sales Line Type"::Item));
        SalesLine.FindFirst();
        Assert.AreNotEqual('', SalesLine."PTSS Credit-to Doc. No.", CreditToDocErr);
        Assert.AreNotEqual('', SalesLine."PTSS Credit-to Doc. Line No.", CreditToDocLineErr);
    end;

    procedure ItemLedgerEntryHasTaxFieldsFilled(SalesHeader1: Record "Sales Header"; Item: Record Item)
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetFilter("Item No.", Item."No.");
        ItemLedgerEntry.SetFilter("Entry Type", Format(ItemLedgerEntry."Entry Type"::Sale));
        ItemLedgerEntry.FindFirst();
        ItemLedgerEntry.TestField("PTSS Product ID");
        ItemLedgerEntry.TestField("PTSS Compensation Tax");
        ItemLedgerEntry.TestField("PTSS Tax Amount");
        ItemLedgerEntry.TestField("PTSS Unit Tax Amount");
    end;

    procedure GLAccIncBalFieldIs(AccNo: Code[20]; IncBalType: Text)
    var
        GLAcc: Record "G/L Account";
    begin
        GLAcc.Get(AccNo);
        Assert.AreEqual(IncBalType, Format(GLAcc."Income/Balance"), WrongIncBalTypeErr);
    end;

    procedure GLAccTotalingIsNotEmpty(AccNo: Code[20])
    var
        GLAcc: Record "G/L Account";
    begin
        GLAcc.Get(AccNo);
        Assert.AreNotEqual('', GLAcc.Totaling, TotalingEmptyErr);
    end;

    procedure GLEntryHasCreditAmountFieldFilled(SalesHeader: Record "Sales Header")
    var
        GLEntry: Record "G/L Entry";
    begin
        GLEntry.FindFirst();
        GLEntry.SetFilter("Document No.", 'P' + SalesHeader."No.");

        GLEntry.TestField("Credit Amount");
    end;

    procedure TerritorialCodeExistsAndHasFiveOptions(SalesInvoice: Record "Sales Header")
    var
        SalesInvPage: TestPage "Sales Invoice";
        SalesLine: Record "Sales Line";
        ListOfOptions: List of [Text];
        ListOfExpectedOptions: List Of [Text];
        NumOfOptions, i : Integer;
    begin
        ListOfExpectedOptions.Add(' ');
        ListOfExpectedOptions.Add('1 - Art.º 4.º n.º 1 CIS');
        ListOfExpectedOptions.Add('2 - Art.º 4.º n.º 2 CIS');
        ListOfExpectedOptions.Add('3 - Art.º 4.º n.º 7 CIS');
        ListOfExpectedOptions.Add('4 - Art.º 4.º n.º 8 CIS');

        SalesLine.SetFilter("Document No.", SalesInvoice."No.");
        SalesLine.FindFirst();

        ListOfOptions := SalesLine."PTSS Territoriality Code".Names;
        NumOfOptions := ListOfOptions.Count;
        Assert.AreEqual(5, NumOfOptions, ValueDifErr);
        i := 0;

        repeat
            Assert.AreEqual(ListOfExpectedOptions.Get(i + 1), ListOfOptions.Get(i + 1), ValueDifErr);
            i += 1;
        until i = NumOfOptions;
    end;

    procedure StampDutyAmountWasCalculated(StampDuty: Record "PTSS Stamp Duty General Table")
    var
        StampLedgEntries: Record "PTSS Stamp Duty Ledger Entries";
    begin
        StampLedgEntries.SetFilter("Stamp Duty code", StampDuty."No.");
        StampLedgEntries.FindFirst();
        //Assert.AreEqual(0, StampLedgEntries."Base Amount", ValueDifErr);
    end;

    procedure BlockedFieldExists()
    var
        StampDuty: TestPage "PTSS Stamp Duty General Table";
    begin
        //TODO Teste Comentado até disponibilizar campo na pág.
        // StampDuty.OpenEdit();
        // StampDuty.IsBlocked.SetValue(true);
    end;

    procedure CustomerCardHasBPStatsFields(Customer: Record Customer; BPStat: Record "PTSS BP Statistic")
    var
        CustCardPage: TestPage "Customer Card";
    begin
        CustCardPage.OpenEdit();
        CustCardPage.GoToRecord(Customer);
        CustCardPage."PTSS Debit Pos. Stat. Code".SetValue(BPStat.Code);
        CustCardPage."PTSS Credit Pos. Stat. Code".SetValue(BPStat.Code);
        CustCardPage."PTSS BP Statistic Code".SetValue(BPStat.Code);
    end;

    procedure VendorCardHasBPStatsFields(Vendor: Record Vendor; BPStat: Record "PTSS BP Statistic")
    var
        VendCardPage: TestPage "Vendor Card";
    begin
        VendCardPage.OpenEdit();
        VendCardPage.GoToRecord(Vendor);
        VendCardPage."PTSS Debit Pos. Stat. Code".SetValue(BPStat.Code);
        VendCardPage."PTSS Credit Pos. Stat. Code".SetValue(BPStat.Code);
        VendCardPage."PTSS BP Statistic Code".SetValue(BPStat.Code);
    end;

    procedure GeneralJournalHasBPFields(BPAccType: Record "PTSS BP Account Type"; BPStat: Record "PTSS BP Statistic"; BPTerritory: Record "PTSS BP Territory")
    var
        GenJournalLine: Record "Gen. Journal Line";
    begin
        GenJournalLine."PTSS BP Account Type Code" := BPAccType.Code;
        GenJournalLine."PTSS BP Statistic Code" := BPStat.Code;
        GenJournalLine."PTSS BP Bal. Active Ctry. Code" := BPTerritory.Code;
        GenJournalLine."PTSS BP Bal. Count. Ctry. Code" := BPTerritory.Code;
        GenJournalLine."PTSS BP Bal. NPC 2nd Interv." := 1;
        GenJournalLine."PTSS BP Bal. Statistic Code" := BPStat.Code;
        GenJournalLine."PTSS BP Countrpt. Country Code" := BPTerritory.Code;
        GenJournalLine."PTSS BP NPC 2nd Intervener" := 1;
        GenJournalLine."PTSS BP Statistic Code" := BPStat.Code;
    end;

    procedure BPLedgerEntryExists()
    var
        BPLedgEnt: Record "PTSS BP Ledger Entry";
    begin
        BPLedgEnt.FindFirst();
    end;

    procedure CustomerCardHasChargesFields(var CustCardPage: TestPage "Customer Card")
    begin
        CustCardPage."PTSS Cash VAT Customer".SetValue(true);
        CustCardPage."PTSS Create Receipt".SetValue(true);
    end;

    procedure ATItemCategories(ItemCategory: Record "Item Category")
    var
        ListOfOptions: List of [Text];
        ListOfExpectedOptions: List of [Text];
        NumOfOptions, i : Integer;
    begin
        ListOfExpectedOptions.Add('M - Mercadorias');
        ListOfExpectedOptions.Add('P - Matérias-primas subsidiárias e de consumo');
        ListOfExpectedOptions.Add('A - Produtos acabados e intermédios');
        ListOfExpectedOptions.Add('S - Subprodutos desperdícios e refugos');
        ListOfExpectedOptions.Add('T - Produtos e trabalhos em curso');

        ListOfOptions.Add(Format(ItemCategory."PTSS AT Item Category"::"M - Goods"));
        ListOfOptions.Add(Format(ItemCategory."PTSS AT Item Category"::"P - Raw materials subsidiaries and consumables"));
        ListOfOptions.Add(Format(ItemCategory."PTSS AT Item Category"::"A - Finished and intermediate goods"));
        ListOfOptions.Add(Format(ItemCategory."PTSS AT Item Category"::"S - By-products waste and scrap"));
        ListOfOptions.Add(Format(ItemCategory."PTSS AT Item Category"::"T - Products and work in progress"));

        NumOfOptions := ListOfOptions.Count;
        Assert.AreEqual(5, NumOfOptions, ValueDifErr);
        i := 0;

        repeat
            Assert.AreEqual(ListOfExpectedOptions.Get(i + 1), ListOfOptions.Get(i + 1), ValueDifErr);
            i += 1;
        until i = NumOfOptions;
    end;

    procedure LocationTypes(Location: Record Location)
    var
        ListOfOptions: List of [Text];
        ListOfExpectedOptions: List of [Text];
        NumOfOptions, i : Integer;
    begin
        ListOfExpectedOptions.Add('Internal');
        ListOfExpectedOptions.Add('External - Customer');
        ListOfExpectedOptions.Add('External - Vendor');

        ListOfOptions := Location."PTSS Location Type".Names;
        NumOfOptions := ListOfOptions.Count;
        Assert.AreEqual(3, NumOfOptions, ValueDifErr);
        i := 0;

        repeat
            Assert.AreEqual(ListOfExpectedOptions.Get(i + 1), ListOfOptions.Get(i + 1), ValueDifErr);
            i += 1;
        until i = NumOfOptions;
    end;

    procedure TransferOrderHasSameTypeAndExtEntityNoAsLocationTo(TransferHeader: Record "Transfer Header"; LocationTo: Record Location)
    begin
        Assert.AreEqual(LocationTo."PTSS Location Type", TransferHeader."PTSS Location Type", ValueDifErr);
        Assert.AreEqual(LocationTo."PTSS External Entity No.", TransferHeader."PTSS External Entity No.", ValueDifErr);
    end;

    procedure WorkingDocRelativeToDocWasCreated(SalesHeaderNo: code[20]; Status: Text[1])
    var
        WorkingDoc: Record "PTSS Working Documents Header";
    begin
        Assert.TableIsNotEmpty(Database::"PTSS Working Documents Header");

        WorkingDoc.SetRange("Source Document No.", SalesHeaderNo);
        case Status of
            'F':
                begin
                    WorkingDoc.SetRange("Working Doc. Status", WorkingDoc."Working Doc. Status"::F);
                end;
            'A':
                begin
                    WorkingDoc.SetRange("Working Doc. Status", WorkingDoc."Working Doc. Status"::A);
                end;
            'N':
                begin
                    WorkingDoc.SetRange("Working Doc. Status", WorkingDoc."Working Doc. Status"::N);
                end;
        end;
        if not WorkingDoc.FindSet() then begin
            Error('Working Document Not Found');
        end;

        // WorkingDoc.SetFilter("Source Document No.", SalesHeader."No.");
        // WorkingDoc.SetFilter("Working Doc. Status", Status);
        // WorkingDoc.FindFirst();
    end;

    #endregion

    //########################################################################################################################

    #region jalmeida

    internal procedure CheckCorrectCountCustLedgEntry(No: Code[20]; PostingGroup: Code[20])
    var
        custLedgEntry: Record "Cust. Ledger Entry";
        ErrorCount: Label 'Record has wrong entries';
    begin
        if custLedgEntry.FindSet() then begin
            custLedgEntry.SetRange("Customer No.", No);
            custLedgEntry.SetRange("Customer Posting Group", PostingGroup);
            Assert.RecordIsNotEmpty(custLedgEntry);
            Assert.AreEqual(3, custLedgEntry.Count, ErrorCount);
        end else begin
            Error('Didnt find a Cust. Ledger Entry');
        end;

    end;

    internal procedure PostedShipmentHeaderHasCorrectDate(ShipmentDate: Date)
    var

        SalesShipHeader: REcord "Sales Shipment Header";

    begin

        SalesShipHeader.FindLast();
        Assert.AreEqual(SalesShipHeader."Shipment Date", ShipmentDate, 'Wrong Date');
    end;

    internal procedure VerifyVatTest01(AppliedVAT: Record "G/L Account"; PostingInv: Code[20])
    var
        GLEntry: REcord "G/L Entry";
        GLEntryaux: REcord "G/L Entry";
        PostSalesInv: Record "Sales Invoice Header";
        GLaccountAux: Record "G/L Account";
    begin
        PostSalesInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostSalesInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(3, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."G/L Account No." = AppliedVAT."No." then begin
                AppliedVAT.CalcFields(Balance);
                Assert.AreEqual(-920, AppliedVAT.Balance, ValueDifErr);
            end;
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Sale then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(-4000, GLaccountAux.Balance, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(4920, GLaccountAux.Balance, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    internal procedure VerifyVatTest02(AppliedVAT: Record "G/L Account"; PostingInv: Code[20])
    var
        GLEntry: REcord "G/L Entry";
        GLEntryAcc: REcord "G/L Entry";
        PostSalesInv: Record "Sales Invoice Header";
        GLaccountAux: Record "G/L Account";
    begin
        PostSalesInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostSalesInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(3, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."G/L Account No." = AppliedVAT."No." then begin
                AppliedVAT.CalcFields(Balance);
                Assert.AreEqual(-520, AppliedVAT.Balance, ValueDifErr);
            end;
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Sale then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLEntryAcc.SetRange("G/L Account No.", GLaccountAux."No.");
                GLEntryAcc.SetFilter("Document No.", PostSalesInv."No.");
                GLEntryAcc.FindFirst();

                // GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(-4000, GLEntryAcc.Amount, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLEntryAcc.SetRange("G/L Account No.", GLaccountAux."No.");
                GLEntryAcc.SetFilter("Document No.", PostSalesInv."No.");
                GLEntryAcc.FindFirst();

                // GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(4520, GLEntryAcc.Amount, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    internal procedure VerifyVatTest03(AppliedVAT: Record "G/L Account"; PostingInv: Code[20])
    var
        GLEntry, GLEntryaux, GLEntryAcc : REcord "G/L Entry";
        PostSalesInv: Record "Sales Invoice Header";
        GLaccountAux: Record "G/L Account";
    begin
        PostSalesInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostSalesInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(3, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."G/L Account No." = AppliedVAT."No." then begin
                AppliedVAT.CalcFields(Balance);
                Assert.AreEqual(-120, AppliedVAT.Balance, ValueDifErr);
            end;
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Sale then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLEntryAcc.SetRange("G/L Account No.", GLaccountAux."No.");
                GLEntryAcc.SetFilter("Document No.", PostSalesInv."No.");
                GLEntryAcc.FindFirst();

                Assert.AreEqual(-2000, GLEntryAcc.Amount, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLEntryAcc.SetRange("G/L Account No.", GLaccountAux."No.");
                GLEntryAcc.SetFilter("Document No.", PostSalesInv."No.");
                GLEntryAcc.FindFirst();

                Assert.AreEqual(2120, GLEntryAcc.Amount, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    internal procedure VerifyVatTest04(PostingInv: Code[20])
    var
        GLEntry, GLEntryaux, GLEntryAcc : REcord "G/L Entry";
        PostSalesInv: Record "Sales Invoice Header";
        GLaccountAux: Record "G/L Account";
    begin
        PostSalesInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostSalesInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(2, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Sale then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLEntryAcc.SetRange("G/L Account No.", GLaccountAux."No.");
                GLEntryAcc.SetFilter("Document No.", PostSalesInv."No.");
                GLEntryAcc.FindFirst();

                Assert.AreEqual(-4000, GLEntryAcc.Amount, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLEntryAcc.SetRange("G/L Account No.", GLaccountAux."No.");
                GLEntryAcc.SetFilter("Document No.", PostSalesInv."No.");
                GLEntryAcc.FindFirst();

                Assert.AreEqual(4000, GLEntryAcc.Amount, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    internal procedure VerifyVatTest05(PostingInv: Code[20])
    var
        GLEntry, GLEntryaux, GLEntryAcc : REcord "G/L Entry";
        PostSalesInv: Record "Sales Invoice Header";
        GLaccountAux: Record "G/L Account";
    begin
        PostSalesInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostSalesInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(2, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Sale then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLEntryAcc.SetRange("G/L Account No.", GLaccountAux."No.");
                GLEntryAcc.SetFilter("Document No.", PostSalesInv."No.");
                GLEntryAcc.FindFirst();

                Assert.AreEqual(-3000, GLEntryAcc.amount, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLEntryAcc.SetRange("G/L Account No.", GLaccountAux."No.");
                GLEntryAcc.SetFilter("Document No.", PostSalesInv."No.");
                GLEntryAcc.FindFirst();

                Assert.AreEqual(3000, GLEntryAcc.Amount, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    internal procedure VerifyVatTest06(ToGov: Record "G/L Account"; PostingInv: Code[20])
    var
        GLEntry: REcord "G/L Entry";
        GLEntryaux: REcord "G/L Entry";
        PostSalesInv: Record "Sales Cr.Memo Header";
        GLaccountAux: Record "G/L Account";
    begin
        PostSalesInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostSalesInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(3, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."G/L Account No." = ToGov."No." then begin
                ToGov.CalcFields(Balance);
                Assert.AreEqual(920, ToGov.Balance, ValueDifErr);
            end;
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Sale then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(4000, GLaccountAux.Balance, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(-4920, GLaccountAux.Balance, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    internal procedure VerifyVatTest07(ToGov: Record "G/L Account"; PostingInv: Code[20])
    var
        GLEntry: REcord "G/L Entry";
        GLEntryAcc: REcord "G/L Entry";
        PostSalesInv: Record "Sales Cr.Memo Header";
        GLaccountAux: Record "G/L Account";
    begin
        PostSalesInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostSalesInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(3, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."G/L Account No." = ToGov."No." then begin
                ToGov.CalcFields(Balance);
                Assert.AreEqual(130, ToGov.Balance, ValueDifErr);
            end;
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Sale then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLEntryAcc.SetRange("G/L Account No.", GLaccountAux."No.");
                GLEntryAcc.SetFilter("Document No.", PostSalesInv."No.");
                GLEntryAcc.FindFirst();

                // GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(1000, GLEntryAcc.Amount, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLEntryAcc.SetRange("G/L Account No.", GLaccountAux."No.");
                GLEntryAcc.SetFilter("Document No.", PostSalesInv."No.");
                GLEntryAcc.FindFirst();

                // GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(-1130, GLEntryAcc.Amount, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    internal procedure VerifyVatTest08(ToGov: Record "G/L Account"; PostingInv: Code[20])
    var
        GLEntry, GLEntryaux, GLEntryAcc : REcord "G/L Entry";
        PostSalesInv: Record "Sales Cr.Memo Header";
        GLaccountAux: Record "G/L Account";
    begin
        PostSalesInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostSalesInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(3, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."G/L Account No." = ToGov."No." then begin
                ToGov.CalcFields(Balance);
                Assert.AreEqual(120, ToGov.Balance, ValueDifErr);
            end;
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Sale then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLEntryAcc.SetRange("G/L Account No.", GLaccountAux."No.");
                GLEntryAcc.SetFilter("Document No.", PostSalesInv."No.");
                GLEntryAcc.FindFirst();

                Assert.AreEqual(2000, GLEntryAcc.Amount, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLEntryAcc.SetRange("G/L Account No.", GLaccountAux."No.");
                GLEntryAcc.SetFilter("Document No.", PostSalesInv."No.");
                GLEntryAcc.FindFirst();

                Assert.AreEqual(-2120, GLEntryAcc.Amount, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    internal procedure VerifyVatTest09(PostingInv: Code[20])
    var
        GLEntry, GLEntryaux, GLEntryAcc : REcord "G/L Entry";
        PostSalesInv: Record "Sales Cr.Memo Header";
        GLaccountAux: Record "G/L Account";
    begin
        PostSalesInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostSalesInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(2, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Sale then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLEntryAcc.SetRange("G/L Account No.", GLaccountAux."No.");
                GLEntryAcc.SetFilter("Document No.", PostSalesInv."No.");
                GLEntryAcc.FindFirst();

                Assert.AreEqual(1500, GLEntryAcc.Amount, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLEntryAcc.SetRange("G/L Account No.", GLaccountAux."No.");
                GLEntryAcc.SetFilter("Document No.", PostSalesInv."No.");
                GLEntryAcc.FindFirst();

                Assert.AreEqual(-1500, GLEntryAcc.Amount, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    internal procedure VerifyVatTest10(PostingInv: Code[20])
    var
        GLEntry, GLEntryaux, GLEntryAcc : REcord "G/L Entry";
        PostSalesInv: Record "Sales Cr.Memo Header";
        GLaccountAux: Record "G/L Account";
    begin
        PostSalesInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostSalesInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(2, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Sale then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLEntryAcc.SetRange("G/L Account No.", GLaccountAux."No.");
                GLEntryAcc.SetFilter("Document No.", PostSalesInv."No.");
                GLEntryAcc.FindFirst();

                Assert.AreEqual(3000, GLEntryAcc.amount, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLEntryAcc.SetRange("G/L Account No.", GLaccountAux."No.");
                GLEntryAcc.SetFilter("Document No.", PostSalesInv."No.");
                GLEntryAcc.FindFirst();

                Assert.AreEqual(-3000, GLEntryAcc.Amount, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    internal procedure VerifyVatTest11(AppliedVAT: Record "G/L Account"; PostingInv: Code[20])
    var
        GLEntry: REcord "G/L Entry";
        GLEntryaux: REcord "G/L Entry";
        PostSalesInv: Record "Sales Invoice Header";
        GLaccountAux: Record "G/L Account";
    begin
        PostSalesInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostSalesInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(3, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."G/L Account No." = AppliedVAT."No." then begin
                AppliedVAT.CalcFields(Balance);
                Assert.AreEqual(-230, AppliedVAT.Balance, ValueDifErr);
            end;
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Sale then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(-1000, GLaccountAux.Balance, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(1230, GLaccountAux.Balance, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    internal procedure VerifyVatTest12(DeductVAT: Record "G/L Account"; ReverseCharge: Record "G/L Account"; PostingInv: Code[20])
    var
        GLEntry: REcord "G/L Entry";
        GLEntryaux: REcord "G/L Entry";
        PostPurchInv: Record "Purch. Inv. Header";
        GLaccountAux: Record "G/L Account";
    begin
        PostPurchInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostPurchInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(4, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."G/L Account No." = ReverseCharge."No." then begin
                ReverseCharge.CalcFields(Balance);
                Assert.AreEqual(-230, ReverseCharge.Balance, ValueDifErr);
            end;
            if GLEntry."G/L Account No." = DeductVAT."No." then begin
                DeductVAT.CalcFields(Balance);
                Assert.AreEqual(230, DeductVAT.Balance, ValueDifErr);
            end;
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Purchase then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(1000, GLaccountAux.Balance, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(-1000, GLaccountAux.Balance, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    internal procedure VerifyVatTest13(ToCompany: Record "G/L Account"; ToGov: Record "G/L Account"; PostingInv: Code[20])
    var
        GLEntry: REcord "G/L Entry";
        GLEntryaux: REcord "G/L Entry";
        PostPurchInv: Record "Purch. Cr. Memo Hdr.";
        GLaccountAux: Record "G/L Account";
    begin
        PostPurchInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostPurchInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(4, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."G/L Account No." = ToGov."No." then begin
                ToGov.CalcFields(Balance);
                Assert.AreEqual(230, ToGov.Balance, ValueDifErr);
            end;
            if GLEntry."G/L Account No." = ToCompany."No." then begin
                ToCompany.CalcFields(Balance);
                Assert.AreEqual(-230, ToCompany.Balance, ValueDifErr);
            end;
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Purchase then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(-1000, GLaccountAux.Balance, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(1000, GLaccountAux.Balance, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    internal procedure VerifyVatTest14(ReverseCharge: Record "G/L Account"; PostingInv: Code[20])
    var
        GLEntry: REcord "G/L Entry";
        GLEntryaux: REcord "G/L Entry";
        PostPurchInv: Record "Purch. Inv. Header";
        GLaccountAux: Record "G/L Account";
    begin
        PostPurchInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostPurchInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(3, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."G/L Account No." = ReverseCharge."No." then begin
                ReverseCharge.CalcFields(Balance);
                Assert.AreEqual(-230, ReverseCharge.Balance, ValueDifErr);
            end;
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Purchase then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(1230, GLaccountAux.Balance, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(-1000, GLaccountAux.Balance, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    internal procedure VerifyVatTest15(ReverseCharge: Record "G/L Account"; PostingInv: Code[20])
    var
        GLEntry: REcord "G/L Entry";
        GLEntryaux: REcord "G/L Entry";
        PostPurchInv: Record "Purch. Cr. Memo Hdr.";
        GLaccountAux: Record "G/L Account";
    begin
        PostPurchInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostPurchInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(3, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."G/L Account No." = ReverseCharge."No." then begin
                ReverseCharge.CalcFields(Balance);
                Assert.AreEqual(230, ReverseCharge.Balance, ValueDifErr);
            end;
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Purchase then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(-1230, GLaccountAux.Balance, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(1000, GLaccountAux.Balance, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    internal procedure VerifyVatTest16(PostingInv: Code[20])
    var
        GLEntry: REcord "G/L Entry";
        GLEntryaux: REcord "G/L Entry";
        PostPurchInv: Record "Purch. Inv. Header";
        GLaccountAux: Record "G/L Account";
    begin
        PostPurchInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostPurchInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(2, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Purchase then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(1230, GLaccountAux.Balance, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(-1230, GLaccountAux.Balance, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    internal procedure VerifyVatTest17(DeductVAT: Record "G/L Account"; PostingInv: Code[20])
    var
        GLEntry: REcord "G/L Entry";
        GLEntryaux: REcord "G/L Entry";
        PostPurchInv: Record "Purch. Inv. Header";
        GLaccountAux: Record "G/L Account";
    begin
        PostPurchInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostPurchInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(3, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."G/L Account No." = DeductVAT."No." then begin
                DeductVAT.CalcFields(Balance);
                Assert.AreEqual(115, DeductVAT.Balance, ValueDifErr);
            end;
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Purchase then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(1115, GLaccountAux.Balance, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(-1230, GLaccountAux.Balance, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    internal procedure VerifyVatTest18(ToCompany: Record "G/L Account"; PostingInv: Code[20])
    var
        GLEntry: REcord "G/L Entry";
        GLEntryaux: REcord "G/L Entry";
        PostPurchInv: Record "Purch. Cr. Memo Hdr.";
        GLaccountAux: Record "G/L Account";
    begin
        PostPurchInv.get(PostingInv);
        GLEntry.SetRange("Document No.", PostPurchInv."No.");
        GLEntry.FindSet();
        Assert.AreEqual(3, GLEntry.Count(), ValueDifErr);
        // GLaccountAux.get("Sales Account");
        repeat
            if GLEntry."G/L Account No." = ToCompany."No." then begin
                ToCompany.CalcFields(Balance);
                Assert.AreEqual(-115, ToCompany.Balance, ValueDifErr);
            end;
            if GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Purchase then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(-1115, GLaccountAux.Balance, ValueDifErr);
            end;
            if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                GLaccountAux.get(GLEntry."G/L Account No.");
                GLaccountAux.CalcFields(Balance);
                Assert.AreEqual(1230, GLaccountAux.Balance, ValueDifErr);
            end;

        until GLEntry.Next() <= 0;
    end;

    #endregion

    #region DavidP
    procedure VerifyIfGenJournalAndCrMemoHasSettle(Customer: Record Customer; GenJournalLineToSettle: Record "Gen. Journal Line"; SalesHeader: Record "Sales Header")
    var
        CustLedgerEntry, CustLedgerEntry2 : Record "Cust. Ledger Entry";
        RemainingAmount: Decimal;
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        SalesCrMemoHeader.Get(SalesHeader."Last Posting No.");

        CustLedgerEntry.SetRange("Customer No.", Customer."No.");
        CustLedgerEntry.SetRange("Document No.", GenJournalLineToSettle."Document No.");
        CustLedgerEntry.FindSet();

        CustLedgerEntry2.SetRange("Customer No.", Customer."No.");
        CustLedgerEntry2.SetRange("Document No.", SalesCrMemoHeader."No.");
        CustLedgerEntry2.FindSet();

        if (CustLedgerEntry."Remaining Amount" <> 0) and (CustLedgerEntry2."Remaining Amount" <> 0) then begin
            Error(ValueDifErr);
        end;
    end;

    procedure VerifyIfInvoiceAndCrMemoHasSettle(Customer: Record Customer; SalesHeaderToSettle: Record "Sales Header"; SalesHeader: Record "Sales Header")
    var
        CustLedgerEntry, CustLedgerEntry2 : Record "Cust. Ledger Entry";
        RemainingAmount: Decimal;
        SalesInvoiceHeaderToSettle: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        SalesInvoiceHeaderToSettle.get(SalesHeaderToSettle."Last Posting No.");
        SalesCrMemoHeader.Get(SalesHeader."Last Posting No.");

        CustLedgerEntry.SetRange("Customer No.", Customer."No.");
        CustLedgerEntry.SetRange("Document No.", SalesInvoiceHeaderToSettle."No.");
        CustLedgerEntry.FindSet();

        CustLedgerEntry2.SetRange("Customer No.", Customer."No.");
        CustLedgerEntry2.SetRange("Document No.", SalesCrMemoHeader."No.");
        CustLedgerEntry2.FindSet();

        if (CustLedgerEntry."Remaining Amount" <> 0) and (CustLedgerEntry2."Remaining Amount" <> 0) then begin
            Error(ValueDifErr);
        end;
    end;

    procedure VerifyIfStandardJournalWasCreated(GenJouLine: Record "Gen. Journal Line")
    var
        StandardGeneralJournal: Record "Standard General Journal";
        StandardGeneralJournalLine, StandardGeneralJournalLineAUX, StandardGeneralJournalLineAUX2 : Record "Standard General Journal Line";
        GenJourFindError: Label 'General Journal was not found';
    begin
        StandardGeneralJournal.SetRange("Journal Template Name", GenJouLine."Journal Template Name");
        if StandardGeneralJournal.FindSet() then begin
            StandardGeneralJournalLine.SetRange("Journal Template Name", StandardGeneralJournal."Journal Template Name");
            StandardGeneralJournalLine.SetRange("Standard Journal Code", StandardGeneralJournal.Code);
            if StandardGeneralJournalLine.FindSet() then begin
                repeat
                    StandardGeneralJournalLineAUX.TransferFields(GenJouLine, false);
                    StandardGeneralJournalLineAUX2.TransferFields(StandardGeneralJournalLine, false);

                    if format(StandardGeneralJournalLineAUX) <> format(StandardGeneralJournalLineAUX2) then begin
                        Error(GenJourFindError);
                    end;
                until (StandardGeneralJournalLine.Next() = 0) and (GenJouLine.Next() = 0);
            end else begin
                Error(GenJourFindError);
            end;
        end else begin
            Error(GenJourFindError);
        end;
    end;

    procedure VerifyTotalAreEqualWhenDocReleaseReopenPurch(var PurchaseHeader: Record "Purchase Header")
    var
        ReleaseDiscountAmount, ReleaseSubtotalExclVAT, ReleaseTotalExclVAT, ReleaseTotalVAT, ReleaseTotalInclVAT, ReleaseTotalWithh : Decimal;
        ReOpenDiscountAmount, ReOpenSubtotalExclVAT, ReOpenTotalExclVAT, ReOpenTotalVAT, ReOpenTotalInclVAT, ReOpenTotalWithh : Decimal;
        PurchaseLine: Record "Purchase Line";
    begin
        SSLib.ReleasePurchaseDoc(PurchaseHeader);
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetRange("PTSS Withholding Line", false);
        if PurchaseLine.FindSet() then begin
            repeat
                ReleaseSubtotalExclVAT += PurchaseLine."Line Amount";
                ReleaseTotalExclVAT += PurchaseLine.amount;
                ReleaseDiscountAmount += PurchaseLine."Inv. Discount Amount";
                ReleaseTotalInclVAT += PurchaseLine."Amount Including VAT";
                ReleaseTotalVAT += (PurchaseLine."Amount Including VAT" - PurchaseLine.Amount);
            until PurchaseLine.Next() = 0;
            PurchaseLine.Reset();
        end;
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetRange("PTSS Withholding Line", true);
        if PurchaseLine.FindSet() then begin
            repeat
                ReleaseTotalWithh += Abs(PurchaseLine."Line Amount");
            until PurchaseLine.Next() = 0;
            PurchaseLine.Reset();
        end;

        SSLib.ReleasePurchaseDoc(PurchaseHeader);
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetRange("PTSS Withholding Line", false);
        if PurchaseLine.FindSet() then begin
            repeat
                ReOpenSubtotalExclVAT += PurchaseLine."Line Amount";
                ReOpenTotalExclVAT += PurchaseLine.amount;
                ReOpenDiscountAmount += PurchaseLine."Inv. Discount Amount";
                ReOpenTotalInclVAT += PurchaseLine."Amount Including VAT";
                ReOpenTotalVAT += (PurchaseLine."Amount Including VAT" - PurchaseLine.Amount);
            until PurchaseLine.Next() = 0;
            PurchaseLine.Reset();
        end;
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetRange("PTSS Withholding Line", true);
        if PurchaseLine.FindSet() then begin
            repeat
                ReOpenTotalWithh += Abs(PurchaseLine."Line Amount");
            until PurchaseLine.Next() = 0;
            PurchaseLine.Reset();
        end;

        if (ReOpenSubtotalExclVAT <> ReleaseSubtotalExclVAT) or (ReOpenTotalExclVAT <> ReleaseTotalExclVAT) or (ReOpenDiscountAmount <> ReleaseDiscountAmount) or (ReOpenTotalInclVAT <> ReleaseTotalInclVAT) or (ReOpenTotalVAT <> ReleaseTotalVAT) or (ReOpenTotalWithh <> ReleaseTotalWithh) then begin
            Error(ValueDifErr);
        end;
    end;

    procedure VerifyIfReverseTransactionWasMadeCustomer(Customer: Record Customer; GenJouLine: Record "Gen. Journal Line")
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
    begin
        CustLedgerEntry.SetRange("Customer No.", Customer."No.");
        CustLedgerEntry.SetRange("Document No.", GenJouLine."Document No.");
        CustLedgerEntry.SetRange(Reversed, true);
        CustLedgerEntry.SetRange("Posting Date", today + 1);
        if not CustLedgerEntry.FindSet() then begin
            Error(EntryNotFoundError);
        end;
    end;

    procedure VerifyIfReverseTransactionWasMadeVendor(Vendor: Record Vendor; GenJouLine: Record "Gen. Journal Line")
    var
        VendorLedgerEntry: Record "Vendor Ledger Entry";
    begin
        VendorLedgerEntry.SetRange("Vendor No.", Vendor."No.");
        VendorLedgerEntry.SetRange("Document No.", GenJouLine."Document No.");
        VendorLedgerEntry.SetRange(Reversed, true);
        VendorLedgerEntry.SetRange("Posting Date", today + 1);
        if not VendorLedgerEntry.FindSet() then begin
            Error(EntryNotFoundError);
        end;
    end;

    procedure VerifyIfReceiptWasCreated(SalesHeader: Record "Sales Header")
    var
        ReceiptHeader: Record "PTSS Receipt Header";
        ReceiptError: Label 'Receipt was not found';
    begin
        ReceiptHeader.SetRange("Document No.", SalesHeader."Last Posting No.");
        if not ReceiptHeader.FindSet() then begin
            Error(ReceiptError);
        end;
    end;

    procedure VerifySequenceNoGenJournalLine(ExpectedNo: Integer; DocumentCode: Code[20])
    var
        GenJournalLine: Record "Gen. Journal Line";
        DocumentCodeNo: Integer;
    begin
        GenJournalLine.SetRange("Document No.", DocumentCode);
        if GenJournalLine.FindSet() then begin
            Evaluate(DocumentCodeNo, CopyStr(DocumentCode, StrLen(DocumentCode)));
            if DocumentCodeNo <> ExpectedNo then begin
                error('The Line''s Doc. No. is Different Than The Expected.');
            end;
        end;
    end;

    procedure VerifySequenceNoGenJournalLineV2(FirstCode: Code[20]; SecondCode: Code[20])
    var
        GenJournalLine: Record "Gen. Journal Line";
        Document1stCodeNo, Document2ndCodeNo : Integer;
    begin
        // GenJournalLine.SetRange("Document No.", SecondCode);
        // if GenJournalLine.FindSet() then begin
        //     Evaluate(DocumentCodeNo, CopyStr(DocumentCode, StrLen(DocumentCode)));
        //     if DocumentCodeNo <> ExpectedNo then begin
        //         error('The Line''s Doc. No. is Different Than The Expected.');
        //     end;
        // end;

        Evaluate(Document1stCodeNo, CopyStr(FirstCode, StrLen(FirstCode) - 3));
        Evaluate(Document2ndCodeNo, CopyStr(SecondCode, StrLen(SecondCode) - 3));

        if Document2ndCodeNo - Document1stCodeNo <> 1 then begin
            error('The Line''s Doc. No. is Different Than The Expected.');
        end;
    end;

    procedure VerifyTotalAreEqualWhenDocReleaseReopen(var SalesHeader: Record "Sales Header")
    var
        ReleaseDiscountAmount, ReleaseSubtotalExclVAT, ReleaseTotalExclVAT, ReleaseTotalVAT, ReleaseTotalInclVAT, ReleaseTotalWithh : Decimal;
        ReOpenDiscountAmount, ReOpenSubtotalExclVAT, ReOpenTotalExclVAT, ReOpenTotalVAT, ReOpenTotalInclVAT, ReOpenTotalWithh : Decimal;
        SalesLine: Record "Sales Line";
    begin
        SSLib.ReleaseSalesDoc(SalesHeader);
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange("PTSS Withholding Line", false);
        if SalesLine.FindSet() then begin
            repeat
                ReleaseSubtotalExclVAT += SalesLine."Line Amount";
                ReleaseTotalExclVAT += SalesLine.amount;
                ReleaseDiscountAmount += SalesLine."Inv. Discount Amount";
                ReleaseTotalInclVAT += SalesLine."Amount Including VAT";
                ReleaseTotalVAT += (SalesLine."Amount Including VAT" - SalesLine.Amount);
            until SalesLine.Next() = 0;
            SalesLine.Reset();
        end;
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange("PTSS Withholding Line", true);
        if SalesLine.FindSet() then begin
            repeat
                ReleaseTotalWithh += Abs(SalesLine."Line Amount");
            until SalesLine.Next() = 0;
            SalesLine.Reset();
        end;

        SSLib.ReOpenSalesDoc(SalesHeader);
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange("PTSS Withholding Line", false);
        if SalesLine.FindSet() then begin
            repeat
                ReOpenSubtotalExclVAT += SalesLine."Line Amount";
                ReOpenTotalExclVAT += SalesLine.amount;
                ReOpenDiscountAmount += SalesLine."Inv. Discount Amount";
                ReOpenTotalInclVAT += SalesLine."Amount Including VAT";
                ReOpenTotalVAT += (SalesLine."Amount Including VAT" - SalesLine.Amount);
            until SalesLine.Next() = 0;
            SalesLine.Reset();
        end;
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange("PTSS Withholding Line", true);
        if SalesLine.FindSet() then begin
            repeat
                ReOpenTotalWithh += Abs(SalesLine."Line Amount");
            until SalesLine.Next() = 0;
            SalesLine.Reset();
        end;

        if (ReOpenSubtotalExclVAT <> ReleaseSubtotalExclVAT) or (ReOpenTotalExclVAT <> ReleaseTotalExclVAT) or (ReOpenDiscountAmount <> ReleaseDiscountAmount) or (ReOpenTotalInclVAT <> ReleaseTotalInclVAT) or (ReOpenTotalVAT <> ReleaseTotalVAT) or (ReOpenTotalWithh <> ReleaseTotalWithh) then begin
            Error(ValueDifErr);
        end;
    end;

    procedure ExpectingError(ExpectedError: Text)
    var
        LastSystemError: Text;
    begin
        LastSystemError := System.GetLastErrorText();
        Assert.AreEqual(true, LastSystemError.Contains(ExpectedError), UnexpectedErr);
    end;

    procedure VerifyWithholdingInDocument(SalesHeader: Record "Sales Header")
    begin
        if (SalesHeader."PTSS Withholding Tax Code" = '') and (SalesHeader."PTSS Withholding Tax Code 2" = '') then begin
            Error('There are no withholding codes in the document header.');
        end;
    end;

    procedure NoSeriesIsSequential(PreviousDocumentNo: Integer; NextDocumentNo: integer)
    var
        NSeriesSequentialNo: Integer;
    begin
        NSeriesSequentialNo := NextDocumentNo - PreviousDocumentNo;
        if NSeriesSequentialNo <> 1 then begin
            error('No. Series Code is not sequential');
        end
    end;

    procedure HashNoIsSequential(PTSSHash: Text; PTSSLastHashUsed: text)
    begin
        if PTSSHash <> PTSSLastHashUsed then begin
            error('Hash No. is not sequential');
        end
    end;

    procedure WithholdingLedgerEntryForSettlementCrMemo(SalesHeader: Record "Sales Header")
    var
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
        WithTaxLedgerEntry: Record "PTSS With. Tax Ledger Entry";
        Withholding1, Withholding2, TotalExclVAT : Decimal;
    begin
        SalesCrMemoHeader.get(SalesHeader."Last Posting No.");
        SalesCrMemoLine.SetRange(SalesCrMemoLine."Document No.", SalesCrMemoHeader."No.");
        SalesCrMemoLine.SetRange(SalesCrMemoLine."PTSS Withholding Line", true);
        if SalesCrMemoLine.FindSet() then begin
            repeat
                if SalesCrMemoLine."PTSS Withholding Tax Code 1" <> '' then begin
                    Withholding1 += Abs(SalesCrMemoLine.Amount);
                end;
                if SalesCrMemoLine."PTSS Withholding Tax Code 2" <> '' then begin
                    Withholding2 += Abs(SalesCrMemoLine.Amount);
                end;
            until SalesCrMemoLine.Next() = 0;
            SalesCrMemoLine.Reset();
        end;

        SalesCrMemoLine.SetRange(SalesCrMemoLine."Document No.", SalesCrMemoHeader."No.");
        SalesCrMemoLine.SetRange(SalesCrMemoLine."PTSS Withholding Line", false);
        if SalesCrMemoLine.FindSet() then begin
            repeat
                TotalExclVAT += Abs(SalesCrMemoLine.Amount);
            until SalesCrMemoLine.Next() = 0;
            SalesCrMemoLine.Reset();
        end;

        WithTaxLedgerEntry.SetRange("Application Type", SalesHeader."Document Type");
        WithTaxLedgerEntry.SetRange("Application Document No.", SalesCrMemoHeader."No.");
        if WithTaxLedgerEntry.FindSet() then begin
            if (WithTaxLedgerEntry."Document Amount" <> TotalExclVAT) or (WithTaxLedgerEntry."Withholding Original Amount 1" <> Withholding1) or (WithTaxLedgerEntry."Withholding Original Amount 2" <> Withholding2) then begin
                Error(ValueDifErr);
            end;
        end else begin
            Error(DocumentEntryNotFindErr);
        end;
    end;

    procedure VerifyWitholdingTaxLedgerEntry(SalesHeader: Record "Sales Header"; Has2WithholdingTax: Boolean)
    var
        DocumentEntry: Record "Document Entry";
        WithTaxLedgerEntry: Record "PTSS With. Tax Ledger Entry";

        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCRMemoHeader: Record "Sales Cr.Memo Header";
    begin
        SalesInvoiceHeader.get(SalesHeader."Last Posting No.");

        // DocumentEntry.SetRange("Document No.", SalesInvoiceHeader."No.");
        // DocumentEntry.SetRange("Posting Date", SalesInvoiceHeader."Posting Date");
        // if DocumentEntry.FindSet() then begin
        WithTaxLedgerEntry.SetRange("Document No.", SalesInvoiceHeader."No.");
        WithTaxLedgerEntry.SetRange("Document Date", SalesInvoiceHeader."Posting Date");

        if WithTaxLedgerEntry.FindSet() then begin
            if (WithTaxLedgerEntry."Withholding Tax Code 1" <> '') and (WithTaxLedgerEntry."Withholding Tax Code 2" <> '') and not Has2WithholdingTax then begin
                Error('Document generated 2 withholding tax');
            end;
            if (WithTaxLedgerEntry."Withholding Tax Code 1" = '') or (WithTaxLedgerEntry."Withholding Tax Code 2" = '') and Has2WithholdingTax then begin
                Error('Document generated only 1 withholding tax');
            end;
        end;
        // end else begin
        //     Error(DocumentEntryNotFindErr);
        // end;
    end;

    procedure VerifyIfVATEntryGLEntryNDocumentTotalsAreEqual(SalesHeader: Record "Sales Header"; ExpectedTotalAmountExclVAT: Decimal; ExpectedTotalAmountInclVAT: Decimal; ExpectedTotalWithholding: Decimal; ExpectedTotalVATAmount: Decimal)
    var
        GLEntry: Record "G/L Entry";
        VATEntry: Record "VAT Entry";
        SalesLine: Record "Sales Invoice Line";
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        SalesLineTotalAmountExclVAT, SalesLineTotalAmountInclVAT, SalesLineVATAmount, SalesLineTotalVATAmount, SalesLineTotalWithholding : Decimal;
        GLEntryTotalAmountExclVAT, GLEntryTotalVATAmount, GLEntryTotalAmountInclVAT, GLEntryTotalWithhAmount, TotalVATAmount, TotalWithholding : Decimal;
        VATEntryTotalAmountExclVAT, VATEntryTotalVATAmount : Decimal;
        TotalWithholdingAmount: Decimal;
        WithholdingTaxCodes: Record "PTSS Withholding Tax Codes";
        WithTaxLedgerEntry: Record "PTSS With. Tax Ledger Entry";
        SalesHeaderDocumentTypeAUX: Text;
    begin
        SalesHeaderDocumentTypeAUX := Format(SalesHeader."Document Type");
        case SalesHeaderDocumentTypeAUX of
            'Order':
                begin
                    SalesHeaderDocumentTypeAUX := 'Invoice';
                end;
        end;

        case SalesHeaderDocumentTypeAUX of
            'Invoice':
                begin
                    SalesInvoiceHeader.get(SalesHeader."Last Posting No.");

                    SalesLine.setrange("Document No.", SalesHeader."Last Posting No.");
                    if SalesLine.FindSet() then begin
                        repeat
                        begin
                            if SalesLine."PTSS Withholding Line" then begin
                                if SalesLine."PTSS Withholding Tax Code 1" <> '' then begin
                                    WithholdingTaxCodes.Get(SalesLine."PTSS Withholding Tax Code 1");
                                    SalesLineTotalWithholding += SalesLine."VAT Base Amount";
                                end;

                                if SalesLine."PTSS Withholding Tax Code 2" <> '' then begin
                                    WithholdingTaxCodes.Get(SalesLine."PTSS Withholding Tax Code 2");
                                    SalesLineTotalWithholding += SalesLine."VAT Base Amount";
                                end;
                            end else begin

                                SalesLineTotalAmountExclVAT += SalesLine."VAT Base Amount";
                                SalesLineTotalAmountInclVAT += SalesLine."Amount Including VAT";
                                SalesLineVATAmount := SalesLine."Amount Including VAT" - SalesLine."VAT Base Amount";
                                SalesLineTotalVATAmount += SalesLineVATAmount;
                            end;
                            WithholdingTaxCodes.Reset();
                        end;
                        until SalesLine.Next() = 0;

                        Assert.AreEqual(ExpectedTotalAmountExclVAT, SalesLineTotalAmountExclVAT, ValueDifErr);
                        Assert.AreEqual(ExpectedTotalVATAmount, SalesLineTotalVATAmount, ValueDifErr);
                        Assert.AreEqual(ExpectedTotalAmountInclVAT, SalesLineTotalAmountInclVAT, ValueDifErr);
                        Assert.AreEqual(ExpectedTotalWithholding, Abs(SalesLineTotalWithholding), ValueDifErr);

                        GLEntry.SetRange("Document No.", SalesInvoiceHeader."No.");
                        if GLEntry.FindSet() then begin
                            repeat
                                if (GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Sale) and (GLEntry."Gen. Bus. Posting Group" <> '') and (GLEntry."Gen. Prod. Posting Group" <> '') and (GLEntry.Amount < 0) then begin
                                    GLEntryTotalAmountExclVAT += GLEntry.Amount;
                                end;
                                if (GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Sale) and (GLEntry."Gen. Bus. Posting Group" <> '') and (GLEntry."Gen. Prod. Posting Group" <> '') and (GLEntry.Amount > 0) then begin
                                    GLEntryTotalWithhAmount += GLEntry.Amount;
                                end;
                                if (GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::" ") and (GLEntry."Gen. Bus. Posting Group" <> '') and (GLEntry."Gen. Prod. Posting Group" <> '') then begin
                                    GLEntryTotalVATAmount += abs(GLEntry.Amount);
                                end;
                                if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                                    GLEntryTotalAmountInclVAT := abs(GLEntry.Amount);
                                end;
                            until GLEntry.Next() = 0;

                            GLEntryTotalAmountInclVAT += GLEntryTotalWithhAmount;

                            Assert.AreEqual(ExpectedTotalAmountExclVAT, Abs(GLEntryTotalAmountExclVAT), ValueDifErr);
                            Assert.AreEqual(ExpectedTotalVATAmount, GLEntryTotalVATAmount, ValueDifErr);
                            Assert.AreEqual(ExpectedTotalAmountInclVAT, GLEntryTotalAmountInclVAT, ValueDifErr);
                        end;

                        VATEntry.SetRange("Document No.", SalesInvoiceHeader."No.");
                        if VATEntry.FindSet() then begin
                            repeat
                                if VATEntry.Base < 0 then begin
                                    VATEntryTotalAmountExclVAT += VATEntry.Base;
                                end;

                                VATEntryTotalVATAmount += Abs(VATEntry.Amount);
                            until VATEntry.Next() = 0;

                            Assert.AreEqual(ExpectedTotalAmountExclVAT, Abs(VATEntryTotalAmountExclVAT), ValueDifErr);
                            Assert.AreEqual(ExpectedTotalVATAmount, VATEntryTotalVATAmount, ValueDifErr);
                        end;

                        WithTaxLedgerEntry.SetRange("Document No.", SalesInvoiceHeader."No.");
                        if WithTaxLedgerEntry.FindSet() then begin
                            TotalWithholdingAmount := WithTaxLedgerEntry."Withholding Original Amount 1" + WithTaxLedgerEntry."Withholding Original Amount 2";
                            Assert.AreEqual(ExpectedTotalWithholding, TotalWithholdingAmount, ValueDifErr);
                        end;
                    end;
                end;
            'Credit Memo':
                begin
                    SalesCrMemoHeader.get(SalesHeader."Last Posting No.");

                    SalesCrMemoLine.setrange("Document No.", SalesHeader."Last Posting No.");
                    if SalesCrMemoLine.FindSet() then begin
                        repeat
                        begin
                            if not SalesCrMemoLine."PTSS Withholding Line" then begin
                                SalesLineTotalAmountExclVAT += SalesCrMemoLine."VAT Base Amount";
                                SalesLineTotalAmountInclVAT += SalesCrMemoLine."Amount Including VAT";
                                SalesLineVATAmount := SalesCrMemoLine."Amount Including VAT" - SalesCrMemoLine."VAT Base Amount";
                                SalesLineTotalVATAmount += SalesLineVATAmount;
                            end else begin
                                if SalesCrMemoLine."PTSS Withholding Tax Code 1" <> '' then begin
                                    WithholdingTaxCodes.Get(SalesCrMemoLine."PTSS Withholding Tax Code 1");
                                    ExpectedTotalWithholding += SalesCrMemoLine."VAT Base Amount";
                                end;

                                if SalesCrMemoLine."PTSS Withholding Tax Code 2" <> '' then begin
                                    WithholdingTaxCodes.Get(SalesCrMemoLine."PTSS Withholding Tax Code 2");
                                    ExpectedTotalWithholding += SalesCrMemoLine."VAT Base Amount";
                                end;
                            end;
                            WithholdingTaxCodes.Reset();
                        end until SalesCrMemoLine.Next() = 0;

                        Assert.AreEqual(ExpectedTotalAmountExclVAT, SalesLineTotalAmountExclVAT, ValueDifErr);
                        Assert.AreEqual(ExpectedTotalVATAmount, SalesLineTotalVATAmount, ValueDifErr);
                        Assert.AreEqual(ExpectedTotalAmountInclVAT, SalesLineTotalAmountInclVAT, ValueDifErr);
                        Assert.AreEqual(ExpectedTotalWithholding, Abs(SalesLineTotalWithholding), ValueDifErr);

                        GLEntry.SetRange("Document No.", SalesCrMemoHeader."No.");
                        if GLEntry.FindSet() then begin
                            repeat
                                if (GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Sale) and (GLEntry."Gen. Bus. Posting Group" <> '') and (GLEntry."Gen. Prod. Posting Group" <> '') and (GLEntry.Amount > 0) then begin
                                    GLEntryTotalAmountExclVAT += GLEntry.Amount;
                                end;
                                if (GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Sale) and (GLEntry."Gen. Bus. Posting Group" <> '') and (GLEntry."Gen. Prod. Posting Group" <> '') and (GLEntry.Amount < 0) then begin
                                    GLEntryTotalWithhAmount += GLEntry.Amount;
                                end;
                                if (GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::" ") and (GLEntry."Gen. Bus. Posting Group" <> '') and (GLEntry."Gen. Prod. Posting Group" <> '') then begin
                                    GLEntryTotalVATAmount += abs(GLEntry.Amount);
                                end;
                                if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                                    GLEntryTotalAmountInclVAT := abs(GLEntry.Amount);
                                end;
                            until GLEntry.Next() = 0;

                            GLEntryTotalAmountInclVAT -= GLEntryTotalWithhAmount;

                            Assert.AreEqual(ExpectedTotalAmountExclVAT, GLEntryTotalAmountExclVAT, ValueDifErr);
                            Assert.AreEqual(ExpectedTotalVATAmount, GLEntryTotalVATAmount, ValueDifErr);
                            Assert.AreEqual(ExpectedTotalAmountInclVAT, Abs(GLEntryTotalAmountInclVAT), ValueDifErr);
                        end;

                        VATEntry.SetRange("Document No.", SalesCrMemoHeader."No.");
                        if VATEntry.FindSet() then begin
                            repeat
                                if VATEntry.Base > 0 then begin
                                    VATEntryTotalAmountExclVAT += VATEntry.Base;
                                end;

                                VATEntryTotalVATAmount += Abs(VATEntry.Amount);
                            until VATEntry.Next() = 0;

                            Assert.AreEqual(ExpectedTotalAmountExclVAT, Abs(VATEntryTotalAmountExclVAT), ValueDifErr);
                            Assert.AreEqual(ExpectedTotalVATAmount, VATEntryTotalVATAmount, ValueDifErr);
                        end;

                        WithTaxLedgerEntry.SetRange("Document No.", SalesInvoiceHeader."No.");
                        if WithTaxLedgerEntry.FindSet() then begin
                            TotalWithholdingAmount := WithTaxLedgerEntry."Withholding Original Amount 1" + WithTaxLedgerEntry."Withholding Original Amount 2";
                            Assert.AreEqual(ExpectedTotalWithholding, TotalWithholdingAmount, ValueDifErr);
                        end;
                    end;
                end;
        end;
    end;

    procedure VerifyIfVATEntryGLEntryNDocumentTotalsAreEqualPurch(PurchaseHeader: Record "Purchase Header"; ExpectedTotalAmountExclVAT: Decimal; ExpectedTotalAmountInclVAT: Decimal; ExpectedTotalWithholding: Decimal; ExpectedTotalVATAmount: Decimal)
    var
        GLEntry: Record "G/L Entry";
        VATEntry: Record "VAT Entry";
        PurchaseLine: Record "Purch. Inv. Line";
        PurchInvoiceHeader: Record "Purch. Inv. Header";
        PurchaseCrMemoLine: Record "Purch. Cr. Memo Line";
        PurchCrMemoHeader: Record "Purch. Cr. Memo Hdr.";
        PurchLineTotalAmountExclVAT, PurchLineTotalAmountInclVAT, PurchLineVATAmount, PurchLineTotalVATAmount, PurchLineTotalWithholding : Decimal;
        GLEntryTotalAmountExclVAT, GLEntryTotalVATAmount, GLEntryTotalAmountInclVAT, TotalVATAmount, TotalWithholding : Decimal;
        VATEntryTotalAmountExclVAT, VATEntryTotalVATAmount : Decimal;
        TotalWithholdingAmount: Decimal;
        WithholdingTaxCodes: Record "PTSS Withholding Tax Codes";
        WithTaxLedgerEntry: Record "PTSS With. Tax Ledger Entry";
    begin
        case PurchaseHeader."Document Type" of
            PurchaseHeader."Document Type"::Invoice:
                begin
                    PurchInvoiceHeader.get(PurchaseHeader."Last Posting No.");

                    PurchaseLine.setrange("Document No.", PurchaseHeader."Last Posting No.");
                    if PurchaseLine.FindSet() then begin
                        repeat
                        begin
                            if not PurchaseLine."PTSS Withholding Line" then begin
                                PurchLineTotalAmountExclVAT += PurchaseLine."VAT Base Amount";
                                PurchLineTotalAmountInclVAT += PurchaseLine."Amount Including VAT";
                                PurchLineVATAmount := PurchaseLine."Amount Including VAT" - PurchaseLine."VAT Base Amount";
                                PurchLineTotalVATAmount += PurchLineVATAmount;
                            end else begin
                                if PurchaseLine."PTSS Withholding Tax Code 1" <> '' then begin
                                    WithholdingTaxCodes.Get(PurchaseLine."PTSS Withholding Tax Code 1");
                                    ExpectedTotalWithholding += Abs(PurchaseLine."Direct Unit Cost" * PurchaseLine.Quantity * (0.01 * (100 - PurchaseLine."Line Discount %")) * (0.01 * WithholdingTaxCodes.Tax));
                                end;

                                if PurchaseLine."PTSS Withholding Tax Code 2" <> '' then begin
                                    WithholdingTaxCodes.Get(PurchaseLine."PTSS Withholding Tax Code 2");
                                    ExpectedTotalWithholding += Abs(PurchaseLine."Direct Unit Cost" * PurchaseLine.Quantity * (0.01 * (100 - PurchaseLine."Line Discount %")) * (0.01 * WithholdingTaxCodes.Tax));
                                end;
                            end;
                            WithholdingTaxCodes.Reset();
                        end;
                        until PurchaseLine.Next() = 0;

                        WithTaxLedgerEntry.SetRange("Document No.", PurchInvoiceHeader."No.");
                        if WithTaxLedgerEntry.FindSet() then begin
                            TotalWithholdingAmount := WithTaxLedgerEntry."Withholding Original Amount 1" + WithTaxLedgerEntry."Withholding Original Amount 2";
                            Assert.AreEqual(ExpectedTotalWithholding, TotalWithholdingAmount, ValueDifErr);
                        end;

                        Assert.AreEqual(ExpectedTotalAmountExclVAT, PurchLineTotalAmountExclVAT, ValueDifErr);
                        Assert.AreEqual(ExpectedTotalVATAmount, PurchLineTotalVATAmount, ValueDifErr);
                        Assert.AreEqual(ExpectedTotalAmountInclVAT, PurchLineTotalAmountInclVAT, ValueDifErr);

                        GLEntry.SetRange("Document No.", PurchInvoiceHeader."No.");
                        if GLEntry.FindSet() then begin
                            repeat
                                if (GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Purchase) and (GLEntry."Gen. Bus. Posting Group" <> '') and (GLEntry."Gen. Prod. Posting Group" <> '') then begin
                                    GLEntryTotalAmountExclVAT += GLEntry.Amount;
                                end;

                                if (GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::" ") and (GLEntry."Gen. Bus. Posting Group" <> '') and (GLEntry."Gen. Prod. Posting Group" <> '') then begin
                                    GLEntryTotalVATAmount += GLEntry.Amount;
                                end;
                                if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                                    GLEntryTotalAmountInclVAT := GLEntry.Amount;
                                end;
                            until GLEntry.Next() = 0;

                            Assert.AreEqual(ExpectedTotalAmountExclVAT, abs(GLEntryTotalAmountExclVAT), ValueDifErr);
                            Assert.AreEqual(ExpectedTotalVATAmount, abs(GLEntryTotalVATAmount), ValueDifErr);
                            Assert.AreEqual(ExpectedTotalAmountInclVAT, abs(GLEntryTotalAmountInclVAT), ValueDifErr);
                        end;

                        VATEntry.SetRange("Document No.", PurchInvoiceHeader."No.");
                        if VATEntry.FindSet() then begin
                            repeat
                                VATEntryTotalAmountExclVAT += VATEntry.Base;
                                VATEntryTotalVATAmount += VATEntry.Amount;
                            until VATEntry.Next() = 0;

                            Assert.AreEqual(ExpectedTotalAmountExclVAT, Abs(VATEntryTotalAmountExclVAT), ValueDifErr);
                            Assert.AreEqual(ExpectedTotalVATAmount, Abs(VATEntryTotalVATAmount), ValueDifErr);
                        end;


                    end;
                end;
            PurchaseHeader."Document Type"::"Credit Memo":
                begin
                    PurchCrMemoHeader.get(PurchaseHeader."Last Posting No.");

                    PurchaseCrMemoLine.setrange("Document No.", PurchaseHeader."Last Posting No.");
                    if PurchaseCrMemoLine.FindSet() then begin
                        repeat
                        begin
                            if not PurchaseCrMemoLine."PTSS Withholding Line" then begin
                                PurchLineTotalAmountExclVAT += PurchaseCrMemoLine."VAT Base Amount";
                                PurchLineTotalAmountInclVAT += PurchaseCrMemoLine."Amount Including VAT";
                                PurchLineVATAmount := PurchaseCrMemoLine."Amount Including VAT" - PurchaseCrMemoLine."VAT Base Amount";
                                PurchLineTotalVATAmount += PurchLineVATAmount;
                            end else begin
                                if PurchaseCrMemoLine."PTSS Withholding Tax Code 1" <> '' then begin
                                    WithholdingTaxCodes.Get(PurchaseCrMemoLine."PTSS Withholding Tax Code 1");
                                    ExpectedTotalWithholding += Abs(PurchaseCrMemoLine."Direct Unit Cost" * PurchaseCrMemoLine.Quantity * (0.01 * (100 - PurchaseLine."Line Discount %")) * (0.01 * WithholdingTaxCodes.Tax));
                                end;

                                if PurchaseCrMemoLine."PTSS Withholding Tax Code 2" <> '' then begin
                                    WithholdingTaxCodes.Get(PurchaseCrMemoLine."PTSS Withholding Tax Code 2");
                                    ExpectedTotalWithholding += Abs(PurchaseCrMemoLine."Direct Unit Cost" * PurchaseCrMemoLine.Quantity * (0.01 * (100 - PurchaseLine."Line Discount %")) * (0.01 * WithholdingTaxCodes.Tax));
                                end;
                            end;
                            WithholdingTaxCodes.Reset();
                        end;
                        until PurchaseCrMemoLine.Next() = 0;

                        Assert.AreEqual(ExpectedTotalAmountExclVAT, PurchLineTotalAmountExclVAT, ValueDifErr);
                        Assert.AreEqual(ExpectedTotalVATAmount, PurchLineTotalVATAmount, ValueDifErr);
                        Assert.AreEqual(ExpectedTotalAmountInclVAT, PurchLineTotalAmountInclVAT, ValueDifErr);

                        GLEntry.SetRange("Document No.", PurchCrMemoHeader."No.");
                        if GLEntry.FindSet() then begin
                            repeat
                                if (GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Purchase) and (GLEntry."Gen. Bus. Posting Group" <> '') and (GLEntry."Gen. Prod. Posting Group" <> '') then begin
                                    GLEntryTotalAmountExclVAT += GLEntry.Amount;
                                end;

                                if (GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::" ") and (GLEntry."Gen. Bus. Posting Group" <> '') and (GLEntry."Gen. Prod. Posting Group" <> '') then begin
                                    GLEntryTotalVATAmount += GLEntry.Amount;
                                end;
                                if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                                    GLEntryTotalAmountInclVAT := GLEntry.Amount;
                                end;
                            until GLEntry.Next() = 0;

                            Assert.AreEqual(ExpectedTotalAmountExclVAT, abs(GLEntryTotalAmountExclVAT), ValueDifErr);
                            Assert.AreEqual(ExpectedTotalVATAmount, abs(GLEntryTotalVATAmount), ValueDifErr);
                            Assert.AreEqual(ExpectedTotalAmountInclVAT, abs(GLEntryTotalAmountInclVAT), ValueDifErr);
                        end;

                        VATEntry.SetRange("Document No.", PurchCrMemoHeader."No.");
                        if VATEntry.FindSet() then begin
                            repeat
                                VATEntryTotalAmountExclVAT += VATEntry.Base;
                                VATEntryTotalVATAmount += VATEntry.Amount;
                            until VATEntry.Next() = 0;

                            Assert.AreEqual(ExpectedTotalAmountExclVAT, Abs(VATEntryTotalAmountExclVAT), ValueDifErr);
                            Assert.AreEqual(ExpectedTotalVATAmount, Abs(VATEntryTotalVATAmount), ValueDifErr);
                        end;

                        WithTaxLedgerEntry.SetRange("Document No.", PurchCrMemoHeader."No.");
                        if WithTaxLedgerEntry.FindSet() then begin
                            TotalWithholdingAmount := WithTaxLedgerEntry."Withholding Original Amount 1" + WithTaxLedgerEntry."Withholding Original Amount 2";
                            Assert.AreEqual(ExpectedTotalWithholding, TotalWithholdingAmount, ValueDifErr);
                        end;
                    end;
                end;
            PurchaseHeader."Document Type"::Order:
                begin
                    PurchInvoiceHeader.get(PurchaseHeader."Last Posting No.");

                    PurchaseLine.setrange("Document No.", PurchaseHeader."Last Posting No.");
                    if PurchaseLine.FindSet() then begin
                        repeat
                        begin
                            if not PurchaseLine."PTSS Withholding Line" then begin
                                PurchLineTotalAmountExclVAT += PurchaseLine."VAT Base Amount";
                                PurchLineTotalAmountInclVAT += PurchaseLine."Amount Including VAT";
                                PurchLineVATAmount := PurchaseLine."Amount Including VAT" - PurchaseLine."VAT Base Amount";
                                PurchLineTotalVATAmount += PurchLineVATAmount;
                            end else begin
                                if PurchaseLine."PTSS Withholding Tax Code 1" <> '' then begin
                                    WithholdingTaxCodes.Get(PurchaseLine."PTSS Withholding Tax Code 1");
                                    ExpectedTotalWithholding += Abs(PurchaseLine."Direct Unit Cost" * PurchaseLine.Quantity * (0.01 * (100 - PurchaseLine."Line Discount %")) * (0.01 * WithholdingTaxCodes.Tax));
                                end;

                                if PurchaseLine."PTSS Withholding Tax Code 2" <> '' then begin
                                    WithholdingTaxCodes.Get(PurchaseLine."PTSS Withholding Tax Code 2");
                                    ExpectedTotalWithholding += Abs(PurchaseLine."Direct Unit Cost" * PurchaseLine.Quantity * (0.01 * (100 - PurchaseLine."Line Discount %")) * (0.01 * WithholdingTaxCodes.Tax));
                                end;
                            end;
                            WithholdingTaxCodes.Reset();
                        end;
                        until PurchaseLine.Next() = 0;

                        WithTaxLedgerEntry.SetRange("Document No.", PurchInvoiceHeader."No.");
                        if WithTaxLedgerEntry.FindSet() then begin
                            TotalWithholdingAmount := WithTaxLedgerEntry."Withholding Original Amount 1" + WithTaxLedgerEntry."Withholding Original Amount 2";
                            Assert.AreEqual(ExpectedTotalWithholding, TotalWithholdingAmount, ValueDifErr);
                        end;

                        Assert.AreEqual(ExpectedTotalAmountExclVAT, PurchLineTotalAmountExclVAT, ValueDifErr);
                        Assert.AreEqual(ExpectedTotalVATAmount, PurchLineTotalVATAmount, ValueDifErr);
                        Assert.AreEqual(ExpectedTotalAmountInclVAT, PurchLineTotalAmountInclVAT, ValueDifErr);

                        GLEntry.SetRange("Document No.", PurchInvoiceHeader."No.");
                        if GLEntry.FindSet() then begin
                            repeat
                                if (GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::Purchase) and (GLEntry."Gen. Bus. Posting Group" <> '') and (GLEntry."Gen. Prod. Posting Group" <> '') then begin
                                    GLEntryTotalAmountExclVAT += GLEntry.Amount;
                                end;

                                if (GLEntry."Gen. Posting Type" = GLEntry."Gen. Posting Type"::" ") and (GLEntry."Gen. Bus. Posting Group" <> '') and (GLEntry."Gen. Prod. Posting Group" <> '') then begin
                                    GLEntryTotalVATAmount += GLEntry.Amount;
                                end;
                                if (GLEntry."Gen. Bus. Posting Group" = '') and (GLEntry."Gen. Prod. Posting Group" = '') then begin
                                    GLEntryTotalAmountInclVAT := GLEntry.Amount;
                                end;
                            until GLEntry.Next() = 0;

                            Assert.AreEqual(ExpectedTotalAmountExclVAT, abs(GLEntryTotalAmountExclVAT), ValueDifErr);
                            Assert.AreEqual(ExpectedTotalVATAmount, abs(GLEntryTotalVATAmount), ValueDifErr);
                            Assert.AreEqual(ExpectedTotalAmountInclVAT, abs(GLEntryTotalAmountInclVAT), ValueDifErr);
                        end;

                        VATEntry.SetRange("Document No.", PurchInvoiceHeader."No.");
                        if VATEntry.FindSet() then begin
                            repeat
                                VATEntryTotalAmountExclVAT += VATEntry.Base;
                                VATEntryTotalVATAmount += VATEntry.Amount;
                            until VATEntry.Next() = 0;

                            Assert.AreEqual(ExpectedTotalAmountExclVAT, abs(VATEntryTotalAmountExclVAT), ValueDifErr);
                            Assert.AreEqual(ExpectedTotalVATAmount, abs(VATEntryTotalVATAmount), ValueDifErr);
                        end;
                    end;
                end;
        end;
    end;

    #endregion

    var
        NotFoundErr: Label 'The Posted Document Couldn''t be Found.';
        UnexpectedErr: Label 'The Actual Error is Different Than the Expected Error.';
        CreditToDocErr: Label 'The Credit-To Doc. No. Field Is Empty';
        CreditToDocLineErr: Label 'The Credit-To Doc. Line No. Field Is Empty';
        WrongIncBalTypeErr: Label 'The GL Account''s Income/Balance Field has the Wrong Value.';
        TotalingEmptyErr: Label 'The GL Acount''s Totaling Field Is Not Empty.';
        ValueDifErr: Label 'The Actual Field Value Is Different Than the Expected.';
        DocumentEntryNotFindErr: Label 'Document didn t generated the expected Doc. Entry';
        EntryNotFoundError: Label 'Entry was not found';

        Assert: Codeunit "Library Assert";
        SSLib: Codeunit "PTSS Library";
}