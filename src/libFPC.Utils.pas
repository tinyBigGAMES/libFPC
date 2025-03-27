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
  System.Classes,
  System.Math;

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
function  lfpIsValidWin64PE(const AFilePath: string): Boolean;
procedure lfpUpdateIconResource(const AExeFilePath, AIconFilePath: string);
procedure lfpUpdateVersionInfoResource(const PEFilePath: string; const AMajor, AMinor, APatch: Word; const AProductName, ADescription, AFilename, ACompanyName, ACopyright: string);
function  lfpResourceExist(const AResName: string): Boolean;
function  lfpAddResManifestFromResource(const aResName: string; const aModuleFile: string; aLanguage: Integer=1033): Boolean;

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

function lfpIsValidWin64PE(const AFilePath: string): Boolean;
var
  LFile: TFileStream;
  LDosHeader: TImageDosHeader;
  LPEHeaderOffset: DWORD;
  LPEHeaderSignature: DWORD;
  LFileHeader: TImageFileHeader;
begin
  Result := False;

  if not FileExists(AFilePath) then
    Exit;

  LFile := TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyWrite);
  try
    // Check if file is large enough for DOS header
    if LFile.Size < SizeOf(TImageDosHeader) then
      Exit;

    // Read DOS header
    LFile.ReadBuffer(LDosHeader, SizeOf(TImageDosHeader));

    // Check DOS signature
    if LDosHeader.e_magic <> IMAGE_DOS_SIGNATURE then // 'MZ'
      Exit;

      // Validate PE header offset
    LPEHeaderOffset := LDosHeader._lfanew;
    if LFile.Size < LPEHeaderOffset + SizeOf(DWORD) + SizeOf(TImageFileHeader) then
      Exit;

    // Seek to the PE header
    LFile.Position := LPEHeaderOffset;

    // Read and validate the PE signature
    LFile.ReadBuffer(LPEHeaderSignature, SizeOf(DWORD));
    if LPEHeaderSignature <> IMAGE_NT_SIGNATURE then // 'PE\0\0'
      Exit;

   // Read the file header
    LFile.ReadBuffer(LFileHeader, SizeOf(TImageFileHeader));

    // Check if it is a 64-bit executable
    if LFileHeader.Machine <> IMAGE_FILE_MACHINE_AMD64 then   Exit;

    // If all checks pass, it's a valid Win64 PE file
    Result := True;
  finally
    LFile.Free;
  end;
end;

procedure lfpUpdateIconResource(const AExeFilePath, AIconFilePath: string);
type
  TIconDir = packed record
    idReserved: Word;  // Reserved, must be 0
    idType: Word;      // Resource type, 1 for icons
    idCount: Word;     // Number of images in the file
  end;
  PIconDir = ^TIconDir;

  TGroupIconDirEntry = packed record
    bWidth: Byte;            // Width of the icon (0 means 256)
    bHeight: Byte;           // Height of the icon (0 means 256)
    bColorCount: Byte;       // Number of colors in the palette (0 if more than 256)
    bReserved: Byte;         // Reserved, must be 0
    wPlanes: Word;           // Color planes
    wBitCount: Word;         // Bits per pixel
    dwBytesInRes: Cardinal;  // Size of the image data
    nID: Word;               // Resource ID of the icon
  end;

  TGroupIconDir = packed record
    idReserved: Word;  // Reserved, must be 0
    idType: Word;      // Resource type, 1 for icons
    idCount: Word;     // Number of images in the file
    Entries: array[0..0] of TGroupIconDirEntry; // Variable-length array
  end;

  TIconResInfo = packed record
    bWidth: Byte;            // Width of the icon (0 means 256)
    bHeight: Byte;           // Height of the icon (0 means 256)
    bColorCount: Byte;       // Number of colors in the palette (0 if more than 256)
    bReserved: Byte;         // Reserved, must be 0
    wPlanes: Word;           // Color planes (should be 1)
    wBitCount: Word;         // Bits per pixel
    dwBytesInRes: Cardinal;  // Size of the image data
    dwImageOffset: Cardinal; // Offset of the image data in the file
  end;
  PIconResInfo = ^TIconResInfo;

var
  LUpdateHandle: THandle;
  LIconStream: TMemoryStream;
  LIconDir: PIconDir;
  LIconGroup: TMemoryStream;
  LIconRes: PByte;
  LIconID: Word;
  I: Integer;
  LGroupEntry: TGroupIconDirEntry;
begin

  if not FileExists(AExeFilePath) then
    raise Exception.Create('The specified executable file does not exist.');

  if not FileExists(AIconFilePath) then
    raise Exception.Create('The specified icon file does not exist.');

  LIconStream := TMemoryStream.Create;
  LIconGroup := TMemoryStream.Create;
  try
    // Load the icon file
    LIconStream.LoadFromFile(AIconFilePath);

    // Read the ICONDIR structure from the icon file
    LIconDir := PIconDir(LIconStream.Memory);
    if LIconDir^.idReserved <> 0 then
      raise Exception.Create('Invalid icon file format.');

    // Begin updating the executable's resources
    LUpdateHandle := BeginUpdateResource(PChar(AExeFilePath), False);
    if LUpdateHandle = 0 then
      raise Exception.Create('Failed to begin resource update.');

    try
      // Process each icon image in the .ico file
      LIconRes := PByte(LIconStream.Memory) + SizeOf(TIconDir);
      for I := 0 to LIconDir^.idCount - 1 do
      begin
        // Assign a unique resource ID for the RT_ICON
        LIconID := I + 1;

        // Add the icon image data as an RT_ICON resource
        if not UpdateResource(LUpdateHandle, RT_ICON, PChar(LIconID), LANG_NEUTRAL,
          Pointer(PByte(LIconStream.Memory) + PIconResInfo(LIconRes)^.dwImageOffset),
          PIconResInfo(LIconRes)^.dwBytesInRes) then
          raise Exception.CreateFmt('Failed to add RT_ICON resource for image %d.', [I]);

        // Move to the next icon entry
        Inc(LIconRes, SizeOf(TIconResInfo));
      end;

      // Create the GROUP_ICON resource
      LIconGroup.Clear;
      LIconGroup.Write(LIconDir^, SizeOf(TIconDir)); // Write ICONDIR header

      LIconRes := PByte(LIconStream.Memory) + SizeOf(TIconDir);
      // Write each GROUP_ICON entry
      for I := 0 to LIconDir^.idCount - 1 do
      begin
        // Populate the GROUP_ICON entry
        LGroupEntry.bWidth := PIconResInfo(LIconRes)^.bWidth;
        LGroupEntry.bHeight := PIconResInfo(LIconRes)^.bHeight;
        LGroupEntry.bColorCount := PIconResInfo(LIconRes)^.bColorCount;
        LGroupEntry.bReserved := 0;
        LGroupEntry.wPlanes := PIconResInfo(LIconRes)^.wPlanes;
        LGroupEntry.wBitCount := PIconResInfo(LIconRes)^.wBitCount;
        LGroupEntry.dwBytesInRes := PIconResInfo(LIconRes)^.dwBytesInRes;
        LGroupEntry.nID := I + 1; // Match resource ID for RT_ICON

        // Write the populated GROUP_ICON entry to the stream
        LIconGroup.Write(LGroupEntry, SizeOf(TGroupIconDirEntry));

        // Move to the next ICONDIRENTRY
        Inc(LIconRes, SizeOf(TIconResInfo));
      end;

      // Add the GROUP_ICON resource to the executable
      if not UpdateResource(LUpdateHandle, RT_GROUP_ICON, 'MAINICON', LANG_NEUTRAL,
        LIconGroup.Memory, LIconGroup.Size) then
        raise Exception.Create('Failed to add RT_GROUP_ICON resource.');

      // Commit the resource updates
      if not EndUpdateResource(LUpdateHandle, False) then
        raise Exception.Create('Failed to commit resource updates.');
    except
      EndUpdateResource(LUpdateHandle, True); // Discard changes on failure
      raise;
    end;
  finally
    LIconStream.Free;
    LIconGroup.Free;
  end;
end;

procedure lfpUpdateVersionInfoResource(const PEFilePath: string; const AMajor, AMinor, APatch: Word; const AProductName, ADescription, AFilename, ACompanyName, ACopyright: string);
type
  { TVSFixedFileInfo }
  TVSFixedFileInfo = packed record
    dwSignature: DWORD;        // e.g. $FEEF04BD
    dwStrucVersion: DWORD;     // e.g. $00010000 for version 1.0
    dwFileVersionMS: DWORD;    // e.g. $00030075 for version 3.75
    dwFileVersionLS: DWORD;    // e.g. $00000031 for version 0.31
    dwProductVersionMS: DWORD; // Same format as dwFileVersionMS
    dwProductVersionLS: DWORD; // Same format as dwFileVersionLS
    dwFileFlagsMask: DWORD;    // = $3F for version "0011 1111"
    dwFileFlags: DWORD;        // e.g. VFF_DEBUG | VFF_PRERELEASE
    dwFileOS: DWORD;           // e.g. VOS_NT_WINDOWS32
    dwFileType: DWORD;         // e.g. VFT_APP
    dwFileSubtype: DWORD;      // e.g. VFT2_UNKNOWN
    dwFileDateMS: DWORD;       // file date
    dwFileDateLS: DWORD;       // file date
  end;

  { TStringPair }
  TStringPair = record
    Key: string;
    Value: string;
  end;

var
  LHandleUpdate: THandle;
  LVersionInfoStream: TMemoryStream;
  LFixedInfo: TVSFixedFileInfo;
  LDataPtr: Pointer;
  LDataSize: Integer;
  LStringFileInfoStart, LStringTableStart, LVarFileInfoStart: Int64;
  LStringPairs: array of TStringPair;
  LVErsion: string;
  LMajor, LMinor,LPatch: Word;
  LVSVersionInfoStart: Int64;
  LPair: TStringPair;
  LStringInfoEnd, LStringStart: Int64;
  LStringEnd, LFinalPos: Int64;
  LTranslationStart: Int64;

  procedure AlignStream(const AStream: TMemoryStream; const AAlignment: Integer);
  var
    LPadding: Integer;
    LPadByte: Byte;
  begin
    LPadding := (AAlignment - (AStream.Position mod AAlignment)) mod AAlignment;
    LPadByte := 0;
    while LPadding > 0 do
    begin
      AStream.WriteBuffer(LPadByte, 1);
      Dec(LPadding);
    end;
  end;

  procedure WriteWideString(const AStream: TMemoryStream; const AText: string);
  var
    LWideText: WideString;
  begin
    LWideText := WideString(AText);
    AStream.WriteBuffer(PWideChar(LWideText)^, (Length(LWideText) + 1) * SizeOf(WideChar));
  end;

  procedure SetFileVersionFromString(const AVersion: string; out AFileVersionMS, AFileVersionLS: DWORD);
  var
    LVersionParts: TArray<string>;
    LMajor, LMinor, LBuild, LRevision: Word;
  begin
    // Split the version string into its components
    LVersionParts := AVersion.Split(['.']);
    if Length(LVersionParts) <> 4 then
      raise Exception.Create('Invalid version string format. Expected "Major.Minor.Build.Revision".');

    // Parse each part into a Word
    LMajor := StrToIntDef(LVersionParts[0], 0);
    LMinor := StrToIntDef(LVersionParts[1], 0);
    LBuild := StrToIntDef(LVersionParts[2], 0);
    LRevision := StrToIntDef(LVersionParts[3], 0);

    // Set the high and low DWORD values
    AFileVersionMS := (DWORD(LMajor) shl 16) or DWORD(LMinor);
    AFileVersionLS := (DWORD(LBuild) shl 16) or DWORD(LRevision);
  end;

begin
  LMajor := EnsureRange(AMajor, 0, MaxWord);
  LMinor := EnsureRange(AMinor, 0, MaxWord);
  LPatch := EnsureRange(APatch, 0, MaxWord);
  LVersion := Format('%d.%d.%d.0', [LMajor, LMinor, LPatch]);

  SetLength(LStringPairs, 8);
  LStringPairs[0].Key := 'CompanyName';
  LStringPairs[0].Value := ACompanyName;
  LStringPairs[1].Key := 'FileDescription';
  LStringPairs[1].Value := ADescription;
  LStringPairs[2].Key := 'FileVersion';
  LStringPairs[2].Value := LVersion;
  LStringPairs[3].Key := 'InternalName';
  LStringPairs[3].Value := ADescription;
  LStringPairs[4].Key := 'LegalCopyright';
  LStringPairs[4].Value := ACopyright;
  LStringPairs[5].Key := 'OriginalFilename';
  LStringPairs[5].Value := AFilename;
  LStringPairs[6].Key := 'ProductName';
  LStringPairs[6].Value := AProductName;
  LStringPairs[7].Key := 'ProductVersion';
  LStringPairs[7].Value := LVersion;

  // Initialize fixed info structure
  FillChar(LFixedInfo, SizeOf(LFixedInfo), 0);
  LFixedInfo.dwSignature := $FEEF04BD;
  LFixedInfo.dwStrucVersion := $00010000;
  LFixedInfo.dwFileVersionMS := $00010000;
  LFixedInfo.dwFileVersionLS := $00000000;
  LFixedInfo.dwProductVersionMS := $00010000;
  LFixedInfo.dwProductVersionLS := $00000000;
  LFixedInfo.dwFileFlagsMask := $3F;
  LFixedInfo.dwFileFlags := 0;
  LFixedInfo.dwFileOS := VOS_NT_WINDOWS32;
  LFixedInfo.dwFileType := VFT_APP;
  LFixedInfo.dwFileSubtype := 0;
  LFixedInfo.dwFileDateMS := 0;
  LFixedInfo.dwFileDateLS := 0;

  // SEt MS and LS for FileVersion and ProductVersion
  SetFileVersionFromString(LVersion, LFixedInfo.dwFileVersionMS, LFixedInfo.dwFileVersionLS);
  SetFileVersionFromString(LVersion, LFixedInfo.dwProductVersionMS, LFixedInfo.dwProductVersionLS);

  LVersionInfoStream := TMemoryStream.Create;
  try
    // VS_VERSION_INFO
    LVSVersionInfoStart := LVersionInfoStream.Position;

    LVersionInfoStream.WriteData<Word>(0);  // Length placeholder
    LVersionInfoStream.WriteData<Word>(SizeOf(TVSFixedFileInfo));  // Value length
    LVersionInfoStream.WriteData<Word>(0);  // Type = 0
    WriteWideString(LVersionInfoStream, 'VS_VERSION_INFO');
    AlignStream(LVersionInfoStream, 4);

    // VS_FIXEDFILEINFO
    LVersionInfoStream.WriteBuffer(LFixedInfo, SizeOf(TVSFixedFileInfo));
    AlignStream(LVersionInfoStream, 4);

    // StringFileInfo
    LStringFileInfoStart := LVersionInfoStream.Position;
    LVersionInfoStream.WriteData<Word>(0);  // Length placeholder
    LVersionInfoStream.WriteData<Word>(0);  // Value length = 0
    LVersionInfoStream.WriteData<Word>(1);  // Type = 1
    WriteWideString(LVersionInfoStream, 'StringFileInfo');
    AlignStream(LVersionInfoStream, 4);

    // StringTable
    LStringTableStart := LVersionInfoStream.Position;
    LVersionInfoStream.WriteData<Word>(0);  // Length placeholder
    LVersionInfoStream.WriteData<Word>(0);  // Value length = 0
    LVersionInfoStream.WriteData<Word>(1);  // Type = 1
    WriteWideString(LVersionInfoStream, '040904B0'); // Match Delphi's default code page
    AlignStream(LVersionInfoStream, 4);

    // Write string pairs
    for LPair in LStringPairs do
    begin
      LStringStart := LVersionInfoStream.Position;

      LVersionInfoStream.WriteData<Word>(0);  // Length placeholder
      LVersionInfoStream.WriteData<Word>((Length(LPair.Value) + 1) * 2);  // Value length
      LVersionInfoStream.WriteData<Word>(1);  // Type = 1
      WriteWideString(LVersionInfoStream, LPair.Key);
      AlignStream(LVersionInfoStream, 4);
      WriteWideString(LVersionInfoStream, LPair.Value);
      AlignStream(LVersionInfoStream, 4);

      LStringEnd := LVersionInfoStream.Position;
      LVersionInfoStream.Position := LStringStart;
      LVersionInfoStream.WriteData<Word>(LStringEnd - LStringStart);
      LVersionInfoStream.Position := LStringEnd;
    end;

    LStringInfoEnd := LVersionInfoStream.Position;

    // Write StringTable length
    LVersionInfoStream.Position := LStringTableStart;
    LVersionInfoStream.WriteData<Word>(LStringInfoEnd - LStringTableStart);

    // Write StringFileInfo length
    LVersionInfoStream.Position := LStringFileInfoStart;
    LVersionInfoStream.WriteData<Word>(LStringInfoEnd - LStringFileInfoStart);

    // Start VarFileInfo where StringFileInfo ended
    LVarFileInfoStart := LStringInfoEnd;
    LVersionInfoStream.Position := LVarFileInfoStart;

    // VarFileInfo header
    LVersionInfoStream.WriteData<Word>(0);  // Length placeholder
    LVersionInfoStream.WriteData<Word>(0);  // Value length = 0
    LVersionInfoStream.WriteData<Word>(1);  // Type = 1 (text)
    WriteWideString(LVersionInfoStream, 'VarFileInfo');
    AlignStream(LVersionInfoStream, 4);

    // Translation value block
    LTranslationStart := LVersionInfoStream.Position;
    LVersionInfoStream.WriteData<Word>(0);  // Length placeholder
    LVersionInfoStream.WriteData<Word>(4);  // Value length = 4 (size of translation value)
    LVersionInfoStream.WriteData<Word>(0);  // Type = 0 (binary)
    WriteWideString(LVersionInfoStream, 'Translation');
    AlignStream(LVersionInfoStream, 4);

    // Write translation value
    LVersionInfoStream.WriteData<Word>($0409);  // Language ID (US English)
    LVersionInfoStream.WriteData<Word>($04B0);  // Unicode code page

    LFinalPos := LVersionInfoStream.Position;

    // Update VarFileInfo block length
    LVersionInfoStream.Position := LVarFileInfoStart;
    LVersionInfoStream.WriteData<Word>(LFinalPos - LVarFileInfoStart);

    // Update translation block length
    LVersionInfoStream.Position := LTranslationStart;
    LVersionInfoStream.WriteData<Word>(LFinalPos - LTranslationStart);

    // Update total version info length
    LVersionInfoStream.Position := LVSVersionInfoStart;
    LVersionInfoStream.WriteData<Word>(LFinalPos);

    LDataPtr := LVersionInfoStream.Memory;
    LDataSize := LVersionInfoStream.Size;

    // Update the resource
    LHandleUpdate := BeginUpdateResource(PChar(PEFilePath), False);
    if LHandleUpdate = 0 then
      RaiseLastOSError;

    try
      if not UpdateResourceW(LHandleUpdate, RT_VERSION, MAKEINTRESOURCE(1),
         MAKELANGID(LANG_NEUTRAL, SUBLANG_NEUTRAL), LDataPtr, LDataSize) then
        RaiseLastOSError;

      if not EndUpdateResource(LHandleUpdate, False) then
        RaiseLastOSError;
    except
      EndUpdateResource(LHandleUpdate, True);
      raise;
    end;
  finally
    LVersionInfoStream.Free;
  end;
end;

function  lfpResourceExist(const AResName: string): Boolean;
begin
  Result := Boolean((FindResource(HInstance, PChar(AResName), RT_RCDATA) <> 0));
end;

function lfpAddResManifestFromResource(const aResName: string; const aModuleFile: string; aLanguage: Integer): Boolean;
var
  LHandle: THandle;
  LManifestStream: TResourceStream;
begin
  Result := False;

  if not lfpResourceExist(aResName) then Exit;
  if not TFile.Exists(aModuleFile) then Exit;

  LManifestStream := TResourceStream.Create(HInstance, aResName, RT_RCDATA);
  try
    LHandle := WinAPI.Windows.BeginUpdateResourceW(System.PWideChar(aModuleFile), LongBool(False));

    if LHandle <> 0 then
    begin
      Result := WinAPI.Windows.UpdateResourceW(LHandle, RT_MANIFEST, CREATEPROCESS_MANIFEST_RESOURCE_ID, aLanguage, LManifestStream.Memory, LManifestStream.Size);
      WinAPI.Windows.EndUpdateResourceW(LHandle, False);
    end;
  finally
    FreeAndNil(LManifestStream);
  end;
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
