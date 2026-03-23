tableextension 50100 CustomerExt extends Customer
{
    fields
    {
        field(50100; "Active"; Boolean)
        {
            //DataClassification = ToBeClassified;
            Caption = 'Active';
        }
    }
}