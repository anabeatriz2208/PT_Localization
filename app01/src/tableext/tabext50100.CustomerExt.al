tableextension 50100 CustomerExt extends Customer
{
    fields
    {
        field(50100; "Active"; Boolean)
        {
            DataClassification = CustomerContent;
            Caption = 'Active';
        }
    }
}
//teste
