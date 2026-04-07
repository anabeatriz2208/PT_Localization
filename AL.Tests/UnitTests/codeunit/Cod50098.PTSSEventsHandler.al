codeunit 50098 "PTSS Events Handler"
{
    trigger OnRun()
    begin

    end;

    var
        TesterHelper: Codeunit "PTSS Tester Helper";

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterPostSalesDoc', '', false, false)]
    local procedure OnAfterPostSalesDoc(var SalesHeader: Record "Sales Header"; var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line"; SalesShptHdrNo: Code[20]; RetRcpHdrNo: Code[20]; SalesInvHdrNo: Code[20]; SalesCrMemoHdrNo: Code[20]; CommitIsSuppressed: Boolean; InvtPickPutaway: Boolean; var CustLedgerEntry: Record "Cust. Ledger Entry"; WhseShip: Boolean; WhseReceiv: Boolean)
    var
        NoSeriesLine: Record "No. Series Line";
    begin
        NoSeriesLine.Get(SalesHeader."No. Series", 10000);
        if not (NoSeriesLine."PTSS Last No. Posted" = NoSeriesLine."Last No. Used") then begin
            NoSeriesLine."PTSS Last No. Posted" := NoSeriesLine."Last No. Used";
            NoSeriesLine.Modify();
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostCommitSalesDoc', '', false, false)]
    local procedure OnBeforePostCommitSalesDoc(var SalesHeader: Record "Sales Header"; var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line"; PreviewMode: Boolean; var ModifyHeader: Boolean; var CommitIsSuppressed: Boolean; var TempSalesLineGlobal: Record "Sales Line" temporary)
    begin
        CommitIsSuppressed := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnBeforeSetBillToCustomerNo', '', false, false)]
    local procedure MyProcedure(var SalesHeader: Record "Sales Header"; var Cust: Record Customer; var IsHandled: Boolean)
    begin
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforeCheckMandatoryHeaderFields', '', false, false)]
    local procedure MyProcedure2(var SalesHeader: Record "Sales Header"; var IsHandled: Boolean)
    begin
        IsHandled := True;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Record Restriction Mgt.", 'OnBeforeCustomerCheckSalesPostRestrictions', '', false, false)]
    local procedure MyProcedure3(var SalesHeader: Record "Sales Header"; var IsHandled: Boolean)
    begin
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforeCheckCustBlockage', '', false, false)]
    local procedure MyProcedure4(SalesHeader: Record "Sales Header"; CustCode: Code[20]; var ExecuteDocCheck: Boolean; var IsHandled: Boolean; var TempSalesLine: Record "Sales Line" temporary)
    begin
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Inventory Posting To G/L", 'OnBeforeGetInvtPostSetup', '', false, false)]
    local procedure OnBeforeGetInvtPostSetup(var InventoryPostingSetup: Record "Inventory Posting Setup"; LocationCode: Code[10]; InventoryPostingGroup: Code[20]; var GenPostingSetup: Record "General Posting Setup"; var IsHandled: Boolean)
    begin
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Inventory Posting To G/L", 'OnBeforeSetAccNo', '', false, false)]
    local procedure OnBeforeSetAccNo(var InvtPostBuf: Record "Invt. Posting Buffer"; ValueEntry: Record "Value Entry"; AccType: Option; BalAccType: Option; CalledFromItemPosting: Boolean; var IsHandled: Boolean)
    begin
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Check Line", 'OnBeforeErrorIfNegativeAmt', '', false, false)]
    local procedure PTSSOnBeforeErrorIfNegativeAmt(GenJnlLine: Record "Gen. Journal Line"; var RaiseError: Boolean)
    begin
        RaiseError := false;
    end;

    // [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnAfterFinalizePostingOnBeforeCommit', '', false, false)]
    // local procedure OnAfterFinalizePostingOnBeforeCommit(var PurchHeader: Record "Purchase Header"; var PurchRcptHeader: Record "Purch. Rcpt. Header"; var PurchInvHeader: Record "Purch. Inv. Header"; var PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr."; var ReturnShptHeader: Record "Return Shipment Header"; var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line"; PreviewMode: Boolean; CommitIsSupressed: Boolean)
    // begin
    //     TesterHelper.CheckGLMovs(PurchHeader, GenJnlPostLine);

    // end;
}