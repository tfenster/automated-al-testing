codeunit 50104 TestHandling
{
    Subtype = TestRunner;
    TestIsolation = Codeunit;

    var
        Initialized : Boolean;

    local procedure Init()
    var
        CALTestLine : Record "CAL Test Line";
        CALTestResult : Record "CAL Test Result";
        CALTestSuite : Record "CAL Test Suite";
    begin
        if (not Initialized) then begin
            CALTestLine.DeleteAll();
            CALTestResult.DeleteAll();
            CALTestSuite.DeleteAll();
            
            WITH CALTestSuite DO BEGIN
                INIT;
                VALIDATE(Name,'DEFAULT');
                VALIDATE(Description,'Default Suite');
                VALIDATE(Export,FALSE);
                INSERT(TRUE);
            END;

            PublishWS();
            Initialized := true;
        end; 
    end;

    procedure PublishWS()
    var
        AllObj : Record AllObj;
        TenantWebService : Record "Tenant Web Service";
        WebServiceName : Text;
    begin
        
        AllObj.GET(ObjectType::Codeunit,Codeunit::TestHandling);
        WebServiceName := 'TestHandling';
        
        if TenantWebService.GET(ObjectType::Codeunit,WebServiceName) then begin
            ModifyTenantWebService(TenantWebService,AllObj,WebServiceName,true);
            TenantWebService.MODIFY;
        end else begin
            TenantWebService.INIT;
            ModifyTenantWebService(TenantWebService,AllObj,WebServiceName,true);
            TenantWebService.INSERT;
        end;
    end;

    local procedure ModifyTenantWebService(var TenantWebService : Record "Tenant Web Service"; AllObj : Record AllObj; WebServiceName : Text; Published : Boolean)
    begin        
        TenantWebService."Object Type" := AllObj."Object Type";
        TenantWebService."Object ID" := AllObj."Object ID";
        TenantWebService."Service Name" := COPYSTR(WebServiceName,1,MAXSTRLEN(TenantWebService."Service Name"));
        TenantWebService.Published := Published;
    end;

    procedure RunTestCodeunitsCS(codidsAsString: Text)
    var
        codidsAsStringList : List of [Text];
        codidAsString : Text;
        codidsAsIntegerList : List of [Integer];
        codidAsInteger : Integer;
    begin
        codidsAsStringList := codidsAsString.Split(',');
        foreach codidAsString in codidsAsStringList do begin
            Evaluate(codidAsInteger, codidAsString);
            codidsAsIntegerList.Add(codidAsInteger);
        end;
        RunTestCodeunits(codidsAsIntegerList);
    end;

    procedure RunTestCodeunits(codids: List of [Integer])
    var
        i: Integer;
        AllObjWithCaption: Record AllObjWithCaption;
        TestLineNo: Integer;
        CALTestLine: Record "CAL Test Line";
        codid : Integer;
    begin
        Init();
        Clear(CALTestLine);
        foreach codid in codids do begin
            AllObjWithCaption.Get(AllObjWithCaption."Object Type"::Codeunit, codid);
            AddTests('DEFAULT',AllObjWithCaption."Object ID",TestLineNo);
            TestLineNo := TestLineNo + 10000;
        end;

        RunTests('DEFAULT');
    end;

    local procedure AddTests(TestSuiteName : Code[10]; TestCodeunitId : Integer; LineNo : Integer)
    var
        CALTestLine	: Record "CAL Test Line";	
        CALTestRunner : Codeunit "CAL Test Runner";	
        CALTestManagement : Codeunit "CAL Test Management";
    begin
        WITH CALTestLine DO BEGIN
            IF TestLineExists(TestSuiteName,TestCodeunitId) THEN
                EXIT;

            INIT;
            VALIDATE("Test Suite",TestSuiteName);
            VALIDATE("Line No.",LineNo);
            VALIDATE("Line Type","Line Type"::Codeunit);
            VALIDATE("Test Codeunit",TestCodeunitId);
            VALIDATE(Run,TRUE);

            INSERT(TRUE);

            CALTestManagement.SETPUBLISHMODE();
            CALTestRunner.Run(CALTestLine);
        end;
    end;

    local procedure RunTests(TestSuiteName : Code[10])
    var
        CALTestLine	: Record "CAL Test Line";	
        AllObj : Record AllObj;		
        CALTestRunner : Codeunit "CAL Test Runner";	
        CALTestManagement : Codeunit "CAL Test Management";
    begin
        CALTestLine."Test Suite" := TestSuiteName;

        CALTestManagement.SETTESTMODE();
        CALTestRunner.Run(CALTestLine);
    end;

    local procedure TestLineExists(TestSuiteName : Text; TestCodeunitId : Integer) : Boolean
    var
        CALTestLine : Record "CAL Test Line";
    begin
        CALTestLine.SetRange("Test Suite",TestSuiteName);
        CALTestLine.SetRange("Test Codeunit",TestCodeunitId);
        exit(not CALTestLine.IsEmpty());
    end;

    procedure GetResultsForCodeunitsCS(codidsAsString: Text) : Text
    var
        codidsAsStringList : List of [Text];
        codidAsString : Text;
        codidsAsIntegerList : List of [Integer];
        codidAsInteger : Integer;
    begin
        codidsAsStringList := codidsAsString.Split(',');
        foreach codidAsString in codidsAsStringList do begin
            Evaluate(codidAsInteger, codidAsString);
            codidsAsIntegerList.Add(codidAsInteger);
        end;
        exit(GetResultsForCodeunits(codidsAsIntegerList));
    end;

    procedure GetResultsForCodeunits(codids: List of [Integer]): Text
    var
        doc: XmlDocument;
        dec: XmlDeclaration;
        run: XmlElement;
        suite: XmlElement;
        tcase: XmlElement;
        failure: XmlElement;
        message: XmlElement;
        stacktrace: XmlElement;
        callstack: Text;
        testresults: Record "CAL Test Result";
        search: Text;
        node: XmlNode;
        TempBlob: Record TempBlob Temporary;
        outStr: OutStream;
        inStr: InStream;
        codid: Integer;
        resultText: Text;
        i: Integer;
        timeDuration: Time;
    begin
        doc := XmlDocument.Create();
        dec := XmlDeclaration.Create('1.0', 'UTF-8', 'no');
        doc.SetDeclaration(dec);

        // create the root test-run, data will be updated later
        run := XmlElement.Create('test-run');
        run.SetAttribute('name', 'Automated Test Run');
        run.SetAttribute('testcasecount', '0');
        run.SetAttribute('run-date', Format(Today(), 0, '<year4>-<month,2>-<day,2>'));
        run.SetAttribute('start-time', Format(CurrentDateTime(), 0, '<hours,2>:<minutes,2>:<seconds,2>'));
        run.SetAttribute('result', 'Passed');
        run.SetAttribute('passed', '0');
        run.SetAttribute('total', '0');
        run.SetAttribute('failed', '0');
        run.SetAttribute('inconclusive', '0');
        run.SetAttribute('skipped', '0');
        run.SetAttribute('asserts', '0');
        doc.Add(run);

        // get results for all requested Codeunits
        foreach codid in codids do begin
            testresults.SetFilter("Codeunit ID", FORMAT(codid));
            if (testresults.Find('-')) then
                repeat
                    with testresults do begin
                        // check if test-suite already exists and create it if not
                        search := StrSubstNo('/test-run/test-suite[@name="%1"]', "Codeunit Name");
                        if not run.SelectSingleNode(search, node) then begin
                            suite := XmlElement.Create('test-suite');
                            suite.SetAttribute('name', "Codeunit Name");
                            suite.SetAttribute('fullname', "Codeunit Name");
                            suite.SetAttribute('type', 'Assembly');
                            suite.SetAttribute('status', 'Passed');
                            suite.SetAttribute('testcasecount', '0');
                            suite.SetAttribute('result', 'Passed');
                            suite.SetAttribute('passed', '0');
                            suite.SetAttribute('total', '0');
                            suite.SetAttribute('failed', '0');
                            suite.SetAttribute('inconclusive', '0');
                            suite.SetAttribute('skipped', '0');
                            suite.SetAttribute('asserts', '0');
                            run.Add(suite);
                        end;

                        // create the test-case
                        tcase := XmlElement.Create('test-case');
                        case Result of
                            Result::Passed:
                                begin
                                    resultText := 'Passed';
                                    incrementAttribute(suite, 'passed');
                                    incrementAttribute(run, 'passed');
                                end;
                            Result::Failed:
                                begin
                                    resultText := 'Failed';
                                    incrementAttribute(suite, 'failed');
                                    incrementAttribute(run, 'failed');

                                    suite.SetAttribute('status', 'Failed');
                                    run.SetAttribute('result', 'Failed');

                                    failure := XmlElement.Create('failure');
                                    tcase.Add(failure);

                                    message := XmlElement.Create('message', '', "Error Message");
                                    failure.Add(message);

                                    "Call Stack".CreateInStream(inStr, TextEncoding::UTF8);
                                    callstack := inStrToText(inStr);
                                    stacktrace := XmlElement.Create('stack-trace', '', callstack);
                                    failure.Add(stacktrace);
                                end;
                            Result::Inconclusive:
                                begin
                                    resultText := 'Inconclusive';
                                    incrementAttribute(suite, 'inconclusive');
                                    incrementAttribute(run, 'inconclusive');
                                end;
                            Result::Incomplete:
                                begin
                                    resultText := 'Incomplete';
                                end;
                        end;

                        tcase.SetAttribute('id', Format("No."));
                        tcase.SetAttribute('name', "Codeunit Name" + ':' + "Function Name");
                        tcase.SetAttribute('fullname', "Codeunit Name" + ':' + "Function Name");
                        tcase.SetAttribute('result', resultText);
                        timeDuration := 000000T + "Execution Time"; 
                        tcase.SetAttribute('time', FORMAT(timeDuration, 0, '<Hours24,2><Filler Character,0>:<Minutes,2>:<Seconds,2>'));

                        suite.Add(tcase); 

                        // increment parent counters
                        incrementAttribute(suite, 'testcasecount');
                        incrementAttribute(run, 'testcasecount');
                    end;
                until testresults.Next() = 0;
        end;

        TempBlob.Blob.CreateOutStream(outStr, TextEncoding::UTF8);
        doc.WriteTo(outStr);
        TempBlob.Blob.CreateInStream(inStr, TextEncoding::UTF8);

        exit(inStrToText(inStr));
    end;

    local procedure incrementAttribute(var xmlElem: XmlElement; attributeName: Text)
    var
        attribute: XmlAttribute;
        attributeValue: Integer;
    begin
        xmlElem.Attributes().Get(attributeName, attribute);
        Evaluate(attributeValue, attribute.Value());
        xmlElem.SetAttribute(attributeName, format(attributeValue + 1));
    end;

    local procedure inStrToText(inStr: InStream): Text
    var
        temp: Text;
        tb: TextBuilder;
    begin
        while not (inStr.EOS()) do begin
            inStr.ReadText(temp);
            tb.AppendLine(temp);
        end;
        exit(tb.ToText());
    end;
}

/*page 50100 MyPage2
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "CAL Test Result";
    
    layout
    {
        area(Content)
        {
            group(GroupName)
            {
                field(Name; "No.")
                {
                    ApplicationArea = All;
                    
                }
                field(CU; "Codeunit ID")
                {
                    ApplicationArea = All;
                    
                }
                field(CUN; "Codeunit Name")
                {
                    ApplicationArea = All;
                    
                }
            }
        }
    }
    
    actions
    {
        area(Processing)
        {
            action(ActionName)
            {
                ApplicationArea = All;
                
                trigger OnAction()
                var
                    TestHandling : Codeunit TestHandling;
                    codids : Text;
                begin
                    TestHandling.RunTestCodeunitsCS('50101,130411');
                end;
            }
            action(ActionName2)
            {
                ApplicationArea = All;
                
                trigger OnAction()
                var
                    TestHandling : Codeunit TestHandling;
                    codids : Text;
                begin
                    message(TestHandling.GetResultsForCodeunitsCS('50101,130411'));
                end;
            }
        }
    }
    
    var
        myInt: Integer;
}*/
