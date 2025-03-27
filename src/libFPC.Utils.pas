{===============================================================================
   _ _ _    ___ ___  ___ ™
  | (_) |__| __| _ \/ __|
  | | | '_ \ _||  _/ (__
  |_|_|_.__/_| |_|  \___|
 FreePascal in your pocket!

 Copyright © 2024-present tinyBigGAMES™ LLC
 All Rights Reserved.

 https://github.com/tinyBigGAMES/libFPC

 See LICENSE file for license information
===============================================================================}

unit libFPC.Utils;

{$I libFPC.Defines.inc}

interface

uses
  WinApi.Windows,
  System.Types,
  System.Generics.Collections,
  System.SysUtils,
  System.IOUtils,
  System.Classes;

type
  { TlfpCaptureConsoleEvent }
  TlfpCaptureConsoleEvent = procedure(const aSender: Pointer; const aLine: string);

{ TlfpDirectoryStack }
  TlfpDirectoryStack = class
  protected
    FStack: TStack<String>;
  public
    constructor Create(); virtual;
    destructor Destroy; override;
    procedure Push(aPath: string);
    procedure PushFilePath(aFilename: string);
    procedure Pop;
  end;

  { TlfpCmdLine }
  TlfpCmdLine = record
  private
    class var
      FCmdLine: string;
    class function GetCmdLine: PChar; static;
    class function GetParamStr(aParamStr: PChar; var aParam: string): PChar; static;
    //class operator Initialize (out ADest: TCmdLine);
  public
    class function ParamCount: Integer; static;
    class procedure Reset; static;
    class procedure ClearParams; static;
    class procedure AddAParam(const aParam: string); static;
    class procedure AddParams(const aParams: string); static;
    class function ParamStr(aIndex: Integer): string; static;
    class function GetParamValue(const aParamName: string; aSwitchChars: TSysCharSet; aSeperator: Char; var aValue: string): Boolean; overload; static;
    class function GetParamValue(const aParamName: string; var aValue: string): Boolean; overload; static;
    class function GetParam(const aParamName: string): Boolean; static;
  end;

{ Routines }
function  lfpRemoveQuotes(const AText: string): string;
procedure lfpFreeNilObject(const [ref] AObject: TObject);
function  lfpGetEXEPath(): string;
function  lfpGetExeBasePath(const aFilename: string): string;
function  lfpHasConsoleOutput(): Boolean;
function  lfpEmptyFolder(const AFolder: string): Boolean;
function  lfpExpandRelFilename(aBaseFilename, aRelFilename: string): string;
procedure lfpCaptureConsoleOutput(const ATitle: string; const ACommand: PChar; const AParameters: PChar; var AExitCode: DWORD; ASender: Pointer; AEvent: TlfpCaptureConsoleEvent);
function  lfpEnableVirtualTerminalProcessing(): DWORD;

implementation

{ Routines }
function  lfpRemoveQuotes(const AText: string): string;
var
  S: string;
begin
  S := AnsiDequotedStr(aText, '"');
  Result := AnsiDequotedStr(S, '''');
end;

procedure lfpFreeNilObject(const [ref] AObject: TObject);
var
  Temp: TObject;
begin
  if not Assigned(AObject) then Exit;
  Temp := AObject;
  TObject(Pointer(@AObject)^) := nil;
  Temp.Free;
end;

function  lfpGetEXEPath(): string;
begin
  Result := TPath.GetDirectoryName(ParamStr(0));
end;

function  lfpGetExeBasePath(const aFilename: string): string;
begin
  Result := TPath.Combine(lfpGetEXEPath(), aFilename);
end;

function  lfpHasConsoleOutput(): Boolean;
var
  LStdOut: THandle;
  LMode: DWORD;
begin
  LStdOut := GetStdHandle(STD_OUTPUT_HANDLE);
  Result := (LStdOut <> INVALID_HANDLE_VALUE) and GetConsoleMode(LStdOut, LMode);
end;

function lfpEmptyFolder(const AFolder: string): Boolean;
var
  LFiles, LFolders: TStringDynArray;
  LFileOrDir: string;
begin
  Result := True;

  if not TDirectory.Exists(AFolder) then
  begin
    Exit(False);
  end;

  try
    LFiles := TDirectory.GetFiles(AFolder, '*', TSearchOption.soAllDirectories);
    for LFileOrDir in LFiles do
    begin
      try
        TFile.Delete(LFileOrDir);
      except
        on E: Exception do
        begin
          Exit(False);
        end;
      end;
    end;

    // Delete subfolders
    LFolders := TDirectory.GetDirectories(AFolder, '*', TSearchOption.soAllDirectories);
    for LFileOrDir in LFolders do
    begin
      try
        TDirectory.Delete(LFileOrDir, True);
      except
        on E: Exception do
        begin
          Exit(False);
        end;
      end;
    end;
  except
    on E: Exception do
    begin
      Exit(False);
    end;
  end;
end;

function PathCombine(lpszDest: PWideChar; const lpszDir, lpszFile: PWideChar): PWideChar; stdcall; external 'shlwapi.dll' name 'PathCombineW';

function lfpExpandRelFilename(aBaseFilename, aRelFilename: string): string;
var
  buff: array [0 .. MAX_PATH + 1] of WideChar;
begin
  PathCombine(@buff[0], PWideChar(ExtractFilePath(aBaseFilename)),
    PWideChar(aRelFilename));
  Result := string(buff);
end;

procedure ProcessMessages();
var
  LMsg: TMsg;
begin
  while Integer(PeekMessage(LMsg, 0, 0, 0, PM_REMOVE)) <> 0 do
  begin
    TranslateMessage(LMsg);
    DispatchMessage(LMsg);
  end;
end;

procedure lfpCaptureConsoleOutput(const ATitle: string; const ACommand: PChar; const AParameters: PChar; var AExitCode: DWORD; ASender: Pointer; AEvent: TlfpCaptureConsoleEvent);
const
  //CReadBuffer = 2400;
  CReadBuffer = 1024*2;
var
  saSecurity: TSecurityAttributes;
  hRead: THandle;
  hWrite: THandle;
  suiStartup: TStartupInfo;
  piProcess: TProcessInformation;
  pBuffer: array [0 .. CReadBuffer] of AnsiChar;
  dBuffer: array [0 .. CReadBuffer] of AnsiChar;
  dRead: DWORD;
  dRunning: DWORD;
  dAvailable: DWORD;
  CmdLine: string;
  BufferList: TStringList;
  Line: string;
  LExitCode: DWORD;
begin
  saSecurity.nLength := SizeOf(TSecurityAttributes);
  saSecurity.bInheritHandle := true;
  saSecurity.lpSecurityDescriptor := nil;
  if CreatePipe(hRead, hWrite, @saSecurity, 0) then
    try
      FillChar(suiStartup, SizeOf(TStartupInfo), #0);
      suiStartup.cb := SizeOf(TStartupInfo);
      suiStartup.hStdInput := hRead;
      suiStartup.hStdOutput := hWrite;
      suiStartup.hStdError := hWrite;
      suiStartup.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
      suiStartup.wShowWindow := SW_HIDE;
      if ATitle.IsEmpty then
        suiStartup.lpTitle := nil
      else
        suiStartup.lpTitle := PChar(ATitle);
      CmdLine := ACommand + ' ' + AParameters;
      if CreateProcess(nil, PChar(CmdLine), @saSecurity, @saSecurity, true, NORMAL_PRIORITY_CLASS, nil, nil, suiStartup, piProcess) then
        try
          BufferList := TStringList.Create;
          try
            repeat
              dRunning := WaitForSingleObject(piProcess.hProcess, 100);
              PeekNamedPipe(hRead, nil, 0, nil, @dAvailable, nil);
              if (dAvailable > 0) then
                repeat
                  dRead := 0;
                  ReadFile(hRead, pBuffer[0], CReadBuffer, dRead, nil);
                  pBuffer[dRead] := #0;
                  OemToCharA(pBuffer, dBuffer);
                  BufferList.Clear;
                  BufferList.Text := string(pBuffer);
                  for line in BufferList do
                  begin
                    if Assigned(AEvent) then
                    begin
                      AEvent(ASender, line);
                    end;
                  end;
                until (dRead < CReadBuffer);
              ProcessMessages;
            until (dRunning <> WAIT_TIMEOUT);

            if GetExitCodeProcess(piProcess.hProcess, LExitCode) then
            begin
              AExitCode := LExitCode;
            end;

          finally
            FreeAndNil(BufferList);
          end;
        finally
          CloseHandle(piProcess.hProcess);
          CloseHandle(piProcess.hThread);
        end;
    finally
      CloseHandle(hRead);
      CloseHandle(hWrite);
    end;
end;

function lfpEnableVirtualTerminalProcessing(): DWORD;
var
  HOut: THandle;
  LMode: DWORD;
begin
  HOut := GetStdHandle(STD_OUTPUT_HANDLE);
  if HOut = INVALID_HANDLE_VALUE then
  begin
    Result := GetLastError;
    Exit;
  end;

  if not GetConsoleMode(HOut, LMode) then
  begin
    Result := GetLastError;
    Exit;
  end;

  LMode := LMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING;
  if not SetConsoleMode(HOut, LMode) then
  begin
    Result := GetLastError;
    Exit;
  end;

  Result := 0;  // Success
end;

{ TlfpDirectoryStack }
constructor TlfpDirectoryStack.Create;
begin
  inherited;
  FStack := TStack<String>.Create;
end;

destructor TlfpDirectoryStack.Destroy;
begin
  FreeAndNil(FStack);
  inherited;
end;

procedure TlfpDirectoryStack.Push(aPath: string);
var
  s: string;
begin
  s := GetCurrentDir;
  FStack.Push(s);
  if not s.IsEmpty then
  begin
    SetCurrentDir(aPath);
  end;
end;

procedure TlfpDirectoryStack.PushFilePath(aFilename: string);
var
  LDir: string;
begin
  LDir := TPath.GetDirectoryName(aFilename);
  if LDir.IsEmpty then Exit;
  Push(LDir);
end;

procedure TlfpDirectoryStack.Pop;
var
  s: string;
begin
  if FStack.Count = 0 then Exit;
  s := FStack.Pop;
  SetCurrentDir(s);
end;

{ TlfpCmdLine }
class function TlfpCmdLine.GetCmdLine: PChar;
begin
  Result := PChar(FCmdLine);
end;

class function TlfpCmdLine.GetParamStr(aParamStr: PChar; var aParam: string): PChar;
var
  i, Len: Integer;
  Start, S: PChar;
begin
  // U-OK
  while True do
  begin
    while (aParamStr[0] <> #0) and (aParamStr[0] <= ' ') do
      Inc(aParamStr);
    if (aParamStr[0] = '"') and (aParamStr[1] = '"') then Inc(aParamStr, 2) else Break;
  end;
  Len := 0;
  Start := aParamStr;
  while aParamStr[0] > ' ' do
  begin
    if aParamStr[0] = '"' then
    begin
      Inc(aParamStr);
      while (aParamStr[0] <> #0) and (aParamStr[0] <> '"') do
      begin
        Inc(Len);
        Inc(aParamStr);
      end;
      if aParamStr[0] <> #0 then
        Inc(aParamStr);
    end
    else
    begin
      Inc(Len);
      Inc(aParamStr);
    end;
  end;

  SetLength(aParam, Len);

  aParamStr := Start;
  S := Pointer(aParam);
  i := 0;
  while aParamStr[0] > ' ' do
  begin
    if aParamStr[0] = '"' then
    begin
      Inc(aParamStr);
      while (aParamStr[0] <> #0) and (aParamStr[0] <> '"') do
      begin
        S[i] := aParamStr^;
        Inc(aParamStr);
        Inc(i);
      end;
      if aParamStr[0] <> #0 then Inc(aParamStr);
    end
    else
    begin
      S[i] := aParamStr^;
      Inc(aParamStr);
      Inc(i);
    end;
  end;

  Result := aParamStr;
end;

class function TlfpCmdLine.ParamCount: Integer;
var
  P: PChar;
  S: string;
begin
  // U-OK
  Result := 0;
  P := TlfpCmdLine.GetParamStr(GetCmdLine, S);
  while True do
  begin
    P := TlfpCmdLine.GetParamStr(P, S);
    if S = '' then Break;
    Inc(Result);
  end;
end;

class procedure TlfpCmdLine.ClearParams;
begin
  FCmdLine := '';
end;

class procedure TlfpCmdLine.Reset;
begin
  // init commandline
  FCmdLine := System.CmdLine + ' ';
end;

class procedure TlfpCmdLine.AddAParam(const aParam: string);
var
  LParam: string;
begin
  LParam := aParam.Trim;
  if LParam.IsEmpty then Exit;
  FCmdLine := FCmdLine + LParam + ' ';
end;

class procedure TlfpCmdLine.AddParams(const aParams: string);
begin
  var LParams := aParams.Split([' '], TStringSplitOptions.ExcludeEmpty);
  for var I := 0 to Length(LParams)-1 do
  begin
    AddAParam(LParams[I]);
  end;
end;

class function TlfpCmdLine.ParamStr(aIndex: Integer): string;
var
  P: PChar;
  Buffer: array[0..260] of Char;
begin
  Result := '';
  if aIndex = 0 then
    SetString(Result, Buffer, GetModuleFileName(0, Buffer, Length(Buffer)))
  else
  begin
    P := GetCmdLine;
    while True do
    begin
      P := TlfpCmdLine.GetParamStr(P, Result);
      if (aIndex = 0) or (Result = '') then Break;
      Dec(aIndex);
    end;
  end;
end;

class function TlfpCmdLine.GetParamValue(const aParamName: string; aSwitchChars: TSysCharSet; aSeperator: Char; var aValue: string): Boolean;
var
  i, Sep: Longint;
  s: string;
begin

  Result := False;
  aValue := '';

  // check for first non switch param when aParamName = '' and no
  // other params are found
  if (aParamName = '') then
  begin
    for i := 1 to TlfpCmdLine.ParamCount do
    begin
      s := TlfpCmdLine.ParamStr(i);
      if Length(s) > 0 then
        // if S[1] in aSwitchChars then
        if not CharInSet(s[1], aSwitchChars) then
        begin
          aValue := s;
          Result := True;
          Exit;
        end;
    end;
    Exit;
  end;

  // check for switch params
  for i := 1 to TlfpCmdLine.ParamCount do
  begin
    s := TlfpCmdLine.ParamStr(i);
    if Length(s) > 0 then
      // if S[1] in aSwitchChars then
      if CharInSet(s[1], aSwitchChars) then

      begin
        Sep := Pos(aSeperator, s);

        case Sep of
          0:
            begin
              if CompareText(Copy(s, 2, Length(s) - 1), aParamName) = 0 then
              begin
                Result := True;
                Break;
              end;
            end;
          1 .. MaxInt:
            begin
              if CompareText(Copy(s, 2, Sep - 2), aParamName) = 0 then
              // if CompareText(Copy(S, 1, Sep -1), aParamName) = 0 then
              begin
                aValue := Copy(s, Sep + 1, Length(s));
                Result := True;
                Break;
              end;
            end;
        end; // case
      end
  end;

end;

// GetParameterValue('p', ['/', '-'], '=', sValue);
class function TlfpCmdLine.GetParamValue(const aParamName: string; var aValue: string): Boolean;
begin
  Result := TlfpCmdLine.GetParamValue(aParamName, ['/', '-'], '=', aValue);
end;

class function TlfpCmdLine.GetParam(const aParamName: string): Boolean;
var
  LValue: string;
begin
  Result := TlfpCmdLine.GetParamValue(aParamName, ['/', '-'], '=', LValue);
  if not Result then
  begin
    Result := SameText(aParamName, TlfpCmdLine.ParamStr(1));
  end;
end;

end.
