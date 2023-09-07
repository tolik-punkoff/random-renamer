program rr;

//{$mode objfpc}{$H+}
//{$codepage UTF8}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, Math, SysUtils, CustApp, FileUtil
  { you can add units after this };

type

  { TRR }

  TRR = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    procedure WriteHelp; virtual;
    function GenName(NumAlph:byte; NameLen:byte; ExtLen:byte):RawByteString; virtual;
    function GetAlphabet(N:Byte):RawByteString; virtual;
    function GenerateString (len:Integer; Pattern:RawByteString): RawByteString; virtual;
    procedure ReverseList(var List: TStringList); virtual;
    procedure WriteIf(Txt:string; W:boolean); virtual;
    procedure WriteLnIf(Txt:string; W:boolean);
  end;

{ TRR }

procedure TRR.DoRun;
var
  Mask, StartDir:string;
  IncludeSubdirs, RenameSubdirs, RenameFiles, Verbose:boolean;
  FilenameLen, ExtensionLen, AlphNumber:byte;

  i:LongInt;
  lstFiles:TStringList=nil; lstDirs:TStringList=nil;
  sNewFileName:RawByteString;
  sNewDirName:RawByteString;
  ctrFoundFiles, ctrRenamedFiles, ctrErrFiles:longint;
  ctrFoundDirs, ctrRenamedDirs, ctrErrDirs, ctrSkipDirs:longint;
  tmpInt:longint;

begin
   //init variables
   Mask:=''; StartDir:='';
   FilenameLen:=8; ExtensionLen:=3; AlphNumber:=0;
   IncludeSubdirs:=false; RenameSubdirs:=false; RenameFiles:=false;
   Verbose:=false;

   i:=0;
   sNewFileName:=''; sNewDirName:='';
   ctrFoundFiles:=0; ctrRenamedFiles:=0; ctrErrFiles:=0;
   ctrFoundDirs:=0; ctrRenamedDirs:=0; ctrErrDirs:=0; ctrSkipDirs:=0;

  // check if no parameters
  if ParamCount=0 then begin
    WriteHelp;
    Terminate;
    Halt(1);
  end;

  //parse parameters
  //print help and exit
  if HasOption('h', '') then begin
    WriteHelp;
    Terminate;
    Halt(1);
  end;
  //mask
  if HasOption('m','') then begin
     Mask:=GetOptionValue('m','');
     if Mask = '' then begin
        WriteHelp;
        Terminate;
        Halt(1);
     end;
     RenameFiles:=true;
  end;
  //start directory
  StartDir:=GetOptionValue('d','');
  if StartDir='' then begin
     StartDir:=GetCurrentDir();
  end;
  //Include subdirs
  IncludeSubdirs:=HasOption('s','');
  //Rename subdirs names
  RenameSubdirs:=HasOption('r','');
  //Verbose mode
  Verbose:=HasOption('v','');

  //Alphabet number
  if (HasOption('a','')) then begin
     //not number
     if not TryStrToInt(GetOptionValue('a',''),tmpInt) then begin
        WriteHelp;
        Terminate;
        Writeln ('ERROR: Alphabet number is not number!');
        Halt(1);
     end;
     if (tmpInt < 0) or (tmpInt > 6) then begin
        WriteHelp;
        Terminate;
        Writeln ('ERROR: Minimal alphabet number = 0, Max = 6!');
        Halt(1);
     end;
     AlphNumber:=tmpInt;
  end;
  //Filename length
  if (HasOption('l','')) then begin
     //not number
     if not TryStrToInt(GetOptionValue('l',''),tmpInt) then begin
        WriteHelp;
        Terminate;
        Writeln ('ERROR: Filename length is not number!');
        Halt(1);
     end;
     if (tmpInt < 1) or (tmpInt > 255) then begin
        WriteHelp;
        Terminate;
        Writeln ('ERROR: Minimal filename length = 0, Max = 255!');
        Halt(1);
     end;
     FilenameLen:=tmpInt;
  end;
  //Extension length
  if (HasOption('x','')) then begin
     //not number
     if not TryStrToInt(GetOptionValue('x',''),tmpInt) then begin
        WriteHelp;
        Terminate;
        Writeln ('ERROR: Extension length is not number!');
        Halt(1);
     end;
     if (tmpInt < 0) or (tmpInt > 255) then begin
        WriteHelp;
        Terminate;
        Writeln ('ERROR: Minimal extension length = 0, Max = 255!');
        Halt(1);
     end;
     ExtensionLen:=tmpInt;
  end;

  //If not -m <mask> and not -t - no main parameters
  if (not RenameFiles) and (not RenameSubdirs) then begin
     WriteHelp;
     Terminate;
     Halt(1);
  end;

  //check if start directory exist
  if not DirectoryExists(StartDir) then begin
     WriteLn('ERROR: Directory ', StartDir, ' not exists!');
     Terminate;
     Halt(1);
  end;

  if RenameFiles then begin
     WriteLnIf('Rename files...',Verbose);
     //Find files by mask
     lstFiles:=TStringList.Create;
     try
       FindAllFiles(lstFiles,StartDir,Mask,IncludeSubdirs);
       i:=0;
       //cycle for find files
       while i < lstFiles.Count do begin
         //get new file name
         sNewFileName := ExtractFilePath(lstFiles[i]) +
                      GenName(AlphNumber, FilenameLen, ExtensionLen);
         //check if new temp name exist
         while FileExists(sNewFileName) do begin
               sNewFileName := ExtractFilePath(lstFiles[i]) +
                      GenName(AlphNumber, FilenameLen, ExtensionLen);
         end;
         inc(ctrFoundFiles); //include counter for found files
         WriteIf(lstFiles[i]+' --> '+ExtractFileName(lstFiles[i])+' --> '+
                 ExtractFileName(sNewFileName),Verbose);
         if RenameFile(lstFiles[i],sNewFileName) then begin
                   WriteLnIf(' OK.',Verbose);
                   inc(ctrRenamedFiles); //inc counter for renamed files
         end
         else begin
              WriteLnIf('Rename error.',Verbose);
              inc(ctrErrFiles); //inc counter for rename errors
         end;
          inc (i); //include list counter
         end; //end cycle
    finally
         lstFiles.Free();
    end;
  end; //end rename files

  //Rename subdirs
  if RenameSubdirs then begin
    WriteLnIf('',Verbose);
    WriteLnIf('Rename directories...', Verbose);
    lstDirs:=TStringList.Create;
     try
       FindAllDirectories(lstDirs,StartDir,IncludeSubdirs);
       i:=0;
       ReverseList(lstDirs);
       //cycle for find dirs
       while i < lstDirs.Count do begin
         //get new dir name
         sNewDirName := ExtractFilePath(lstDirs[i]) +
                      GenName(AlphNumber, FilenameLen, 0);
         //check if new temp name exist
         while DirectoryExists(sNewDirName) do begin
               sNewDirName := ExtractFilePath(lstDirs[i]) +
                      GenName(AlphNumber, FilenameLen, 0);
         end;
         inc(ctrFoundDirs); //include counter for found dirs
         WriteIf(lstDirs[i]+' --> '+ExtractFileName(lstDirs[i])+' --> '+
                 ExtractFileName(sNewDirName),Verbose);
         if RenameFile(lstDirs[i],sNewDirName) then begin
                   WriteLnIf(' OK.',Verbose);
                   inc(ctrRenamedDirs); //inc counter for renamed dirs
         end
         else begin
              WriteLnIf('Rename error.',Verbose);
              inc(ctrErrDirs); //inc counter for rename errors
         end;
          inc (i); //include list counter
         end; //end cycle
     finally
       lstFiles.Free();
     end;
  end; //end translit subdirs

  //write counters
  if RenameFiles then begin
    WriteLnIf('',Verbose);
    WriteLnIf('Found files: ' + IntToStr(ctrFoundFiles),Verbose);
    WriteLnIf('Renamed files: ' + IntToStr(ctrRenamedFiles),Verbose);
    WriteLnIf('Error files: ' + IntToStr(ctrErrFiles),Verbose);
  end;
  if RenameSubdirs then begin
    if RenameFiles then WriteLnIf('',Verbose);
    WriteLnIf('Found directories: ' + IntToStr(ctrFoundDirs),Verbose);
    WriteLnIf('Renamed directories: ' + IntToStr(ctrRenamedDirs),Verbose);
    WriteLnIf('Skip directories: ' + IntToStr(ctrSkipDirs),Verbose);
    WriteLnIf('Error directories: ' + IntToStr(ctrErrDirs),Verbose);
  end;

  //ReadLn();
  // stop program loop
  Terminate;
end;
function TRR.GetAlphabet(N:Byte):RawByteString;
var Arr: array[0..6] of RawByteString;
begin
     Arr[0]:='abcdefghijklmnopqrstuvwxyz0123456789';
     Arr[1]:='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
     Arr[2]:='ABCDEF0123456789';
     Arr[3]:='abcdef0123456789';
     Arr[4]:='0123456789';
     Arr[5]:='abcdefghijklmnopqrstuvwxyz';
     Arr[6]:='ABCDEFGHIJKLMNOPQRSTUVWXYZ';

     exit(Arr[N]);
end;
function TRR.GenerateString (len:Integer; Pattern:RawByteString): RawByteString;
var I:Integer; C:Char;
begin
  Result:='';
  I:=0;
  SetLength(Result,len);

  while I < len do
  begin
       C:=Pattern[RandomRange(1, Length(Pattern))];
       Result[I+1]:=C;
       inc(I);
  end;
end;
procedure TRR.WriteHelp;
var I:byte;
begin
  Writeln ('Random renamer (rr), this program rename files to random names');
  Writeln ('v 0.0.1b (L) ChaosSoftware 2023.');
  WriteLn();
  Writeln('Usage: ',ExtractFileName(ExeName), ' [parameters] | -h');
  WriteLn('-h - this help');
  WriteLn('-m <mask> - file mask for rename. Parameter must be.');
  WriteLn('Or use -r parameter for rename directories only.');
  WriteLn('[-a] <number> - alphabet number');
  WriteLn('[-d] - startup directory, default, current directory');
  WriteLn('[-l] <number> - filename length, default 8');
  WriteLn('[-r] - rename dirs');
  WriteLn('[-s] - include subdirectories');
  WriteLn('[-v] - verbose mode');
  WriteLn('[-x] <number> - extension length, default 3');
  WriteLn('');
  WriteLn('Alphabets:');
  for I:=0 to 6 do begin
      WriteLn (I, ': ', GetAlphabet(I));
  end;
  WriteLn('Default: 0');
end;
function TRR.GenName(NumAlph:byte; NameLen:byte; ExtLen:byte):RawByteString;
var FullName:RawByteString;
begin
  FullName:=GenerateString(NameLen,GetAlphabet(NumAlph));
  if (ExtLen > 0) then begin
     FullName:=FullName + '.' + GenerateString(ExtLen,GetAlphabet(NumAlph));
  end;
  Exit (FullName);
end;
procedure TRR.WriteIf(Txt:string; W:boolean);
begin
  if W then Write(Txt);
end;
procedure TRR.WriteLnIf(Txt:string; W:boolean);
begin
  if W then WriteLn(Txt);
end;
procedure TRR.ReverseList(var List: TStringList);
var
   TmpList: TStringList;
   I: Integer;
begin
   TmpList := TStringList.Create;
   for I := List.Count -1 DownTo 0 do
      TmpList.Append(List[I]);
   List.Assign(TmpList);
   TmpList.Free;
end;

var
  Application: TRR;

begin
  Application:=TRR.Create(nil);
  Application.Title:='rr';
  Application.Run;
  Application.Free;
end.

