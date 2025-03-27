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

unit libFPC;

{$I libFPC.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.StrUtils,
  System.Math,
  System.Zip,
  libFPC.Utils;

type

  /// <summary>
  ///   Event type used for receiving print or diagnostic messages from <c>libFPC</c>.
  /// </summary>
  /// <param name="AText">
  ///   The message text being sent, such as output from the compiler or logging information.
  /// </param>
  /// <param name="AUserData">
  ///   A custom pointer passed during registration, allowing context or state to be preserved
  ///   across event invocations.
  /// </param>
  /// <remarks>
  ///   - This event is typically used to capture compiler messages, errors, or progress updates.
  ///   - It is triggered during operations such as <c>Compile</c> or initialization.
  /// </remarks>
  TlfpPrintEvent = procedure(const AText: string; const AUserData: Pointer);

  /// <summary>
  ///   Defines the type of output module to generate during compilation.
  /// </summary>
  /// <remarks>
  ///   - <c>omUnknown</c>: The output type is not set or detected.
  ///   - <c>omEXE</c>: Generates a standalone executable file.
  ///   - <c>omDLL</c>: Generates a dynamic-link library.
  /// </remarks>
  TlfpOutputModual = (omUnknown, omEXE, omDLL);

  /// <summary>
  ///   Represents the core class of the <c>libFPC</c> library, providing methods and properties
  ///   to configure and control the Free Pascal compiler at runtime.
  /// </summary>
  /// <remarks>
  ///   - This class serves as the primary interface for interacting with the Free Pascal compiler,
  ///     allowing for dynamic compilation and management of Pascal projects.
  ///   - It encapsulates functionalities such as setting project files, configuring compiler options,
  ///     handling output settings, and initiating the compilation process.
  ///   - Instances of <c>TlibFPC</c> can be used to programmatically compile Pascal source code
  ///     into executables, dynamic-link libraries, or other supported output formats.
  /// </remarks>
  TlibFPC = class
  private const
    CDefCmdLine   = '-Mdelphiunicode -vbxiwn -Sm -Si -Sc -FcUTF8 -dlibFPC -uFPC -n -Sv -Xi';
    CCompilerPath = 'ppcx64.exe';
  private type
    TSourceType = (stEXE, stDLL, stUnit);
    TEvent<x> = record
      UserData: Pointer;
      Handler: x;
    end;
    TEvents = record
      Print: TEvent<TlfpPrintEvent>;
    end;
    TProject = record
      Filename: string;
      ExeIconFilename: string;
      AddVersionInfo: Boolean;
      AddExeManifest: Boolean;
      ConsoleApp: Boolean;
      OutputPath: string;
      DebugMode: Boolean;
      SearchPath: string;
      MajorVer: Cardinal;
      MinorVer: Cardinal;
      PatchVer: Cardinal;
      ProductName: string;
      Description: string;
      CompanyName: string;
      Copyright: string;
      Trademark: string;
      Comment: string
    end;
  private
    FEvents: TEvents;
    FProject: TProject;
    FIsInit: Boolean;
    FCmdLine: TStringList;
    FOutputFilename: string;
    FModualType: TlfpOutputModual;
    FExitCode: LongWord;
    FCacheDir: string;
    procedure Header();
    procedure Usage();
    procedure OnCaptureConsole(const ALine: string);
    function  GetCmdLine(): string;
    procedure CleanCmdLine();
    procedure ClearCache();
    procedure AddToCmdLine(const AMsg: string; const AArgs: array of const);
    function  GetDirective(aLine: string; aDirective: string; var aValue: string): Boolean;
    procedure ProcessDirectives(const AFilename: string);
    function  GenerateSource(const AType: TSourceType; var AOutputFilename: string): Boolean;
    function  UpdateManifest(): Boolean;
    function  UpdatePayloadIcon(): Boolean;
    function  UpdatePayloadVersionInfo(): Boolean;
    procedure Print(const AMsg: string; const AArgs: array of const);
    procedure PrintLn(const AMsg: string; const AArgs: array of const);

  public
    /// <summary>
    ///   Initializes a new instance of the <c>libFPC</c> core class,
    ///   setting up internal state for compiler interaction.
    /// </summary>
    /// <remarks>
    ///   - This constructor prepares the instance for further configuration
    ///     such as setting source files, compiler options, or output targets.
    ///   - After creation, use methods like <c>SetSource</c> or <c>SetTarget</c>
    ///     to configure the compilation process.
    /// </remarks>
    constructor Create(); virtual;

    /// <summary>
    ///   Destroys the <c>libFPC</c> instance and releases any resources
    ///   allocated during its lifetime.
    /// </summary>
    /// <remarks>
    ///   - This destructor ensures that all memory and handles used by the
    ///     internal compiler structures or temporary files are properly cleaned up.
    ///   - It is automatically called when the instance goes out of scope or
    ///     is explicitly freed.
    /// </remarks>
    destructor Destroy(); override;

    /// <summary>
    ///   Retrieves the semantic version of the <c>libFPC</c> library.
    /// </summary>
    /// <returns>
    ///   A <c>string</c> in semantic version format (e.g., <c>'1.0.0'</c>) representing
    ///   the current version of the <c>libFPC</c> library.
    /// </returns>
    /// <remarks>
    ///   - This version refers to the <c>libFPC</c> API itself, not the FreePascal
    ///     compiler it wraps.
    ///   - Useful for compatibility checks or runtime diagnostics when embedding
    ///     <c>libFPC</c> in external applications.
    /// </remarks>
    function GetVersion(): string;

    /// <summary>
    ///   Resets the <c>libFPC</c> instance to its default, uninitialized state,
    ///   clearing all previously set properties and configurations.
    /// </summary>
    /// <remarks>
    ///   - After calling <c>Reset</c>, the instance must be reconfigured before
    ///     performing any compilation.
    ///   - This is useful when reusing a single instance across multiple
    ///     independent compilation tasks.
    /// </remarks>
    procedure Reset();

    /// <summary>
    ///   Indicates whether the <c>libFPC</c> instance has been initialized
    ///   and is ready for use.
    /// </summary>
    /// <returns>
    ///   <c>True</c> if the instance is initialized and ready;
    ///   otherwise, <c>False</c>.
    /// </returns>
    /// <remarks>
    ///   - Initialization typically involves locating the compiler binary
    ///     and verifying necessary environment settings.
    ///   - Call this method before invoking compile-time operations
    ///     to ensure the instance is in a valid state.
    /// </remarks>
    function IsInit(): Boolean;

    /// <summary>
    ///   Gets the currently registered print event handler used by <c>libFPC</c>.
    /// </summary>
    /// <returns>
    ///   The <c>TlfpPrintEvent</c> currently assigned to handle output messages.
    /// </returns>
    /// <remarks>
    ///   - Returns <c>nil</c> if no handler has been registered.
    ///   - Use <c>SetPrintEvent</c> to provide a handler for capturing output.
    /// </remarks>
    function GetPrintEvent(): TlfpPrintEvent;

    /// <summary>
    ///   Registers a custom print event handler to receive compiler output or diagnostic messages.
    /// </summary>
    /// <param name="AHandler">
    ///   The <c>TlfpPrintEvent</c> procedure to handle messages.
    /// </param>
    /// <param name="AUserData">
    ///   A user-defined pointer that will be passed to the event each time it is invoked.
    /// </param>
    /// <remarks>
    ///   - This allows output to be redirected to logs, GUI elements, or debug consoles.
    ///   - The handler remains active until explicitly changed or cleared.
    /// </remarks>
    procedure SetPrintEvent(const AHandler: TlfpPrintEvent; const AUserData: Pointer);

    /// <summary>
    ///   Sets the main project source file (.pas) to be used as the entry point for compilation.
    /// </summary>
    /// <param name="AFilename">
    ///   The full path to the Pascal source file that acts as the main entry for the project.
    /// </param>
    /// <remarks>
    ///   - This file typically contains the <c>program</c> or <c>library</c> directive,
    ///     and serves as the root unit for the compilation process.
    ///   - This must be called before invoking <c>Compile</c>.
    /// </remarks>
    procedure SetProjectFilename(const AFilename: string);

    /// <summary>
    ///   Retrieves the current project filename assigned as the entry point for compilation.
    /// </summary>
    /// <returns>
    ///   A <c>string</c> containing the full path to the main project <c>.pas</c> file.
    /// </returns>
    /// <remarks>
    ///   - Returns an empty string if no project file has been set.
    ///   - Use this to verify or log which file will be passed to the compiler.
    /// </remarks>
    function GetProjectFilename(): string;

    /// <summary>
    ///   Sets the directory where the compiled output files (e.g., executables or libraries) will be placed.
    /// </summary>
    /// <param name="APath">
    ///   The full path to the desired output directory.
    /// </param>
    /// <remarks>
    ///   - This method configures the compiler to place all generated binaries in the specified directory.
    ///   - It corresponds to the Free Pascal compiler's <c>-FE</c> command-line option, which sets the executable output path. :contentReference[oaicite:0]{index=0}
    /// </remarks>
    procedure SetOutputPath(const APath: string);

    /// <summary>
    ///   Enables or disables the inclusion of debug information in the compiled output.
    /// </summary>
    /// <param name="AEnable">
    ///   Set to <c>True</c> to include debug information; <c>False</c> to exclude it.
    /// </param>
    /// <remarks>
    ///   - Including debug information is essential for debugging purposes but may increase the size of the compiled output.
    ///   - This method aligns with the Free Pascal compiler's <c>-g</c> command-line option, which generates debugging information for use with debuggers like GDB. :contentReference[oaicite:1]{index=1}
    /// </remarks>
    procedure SetDebugMode(const AEnable: Boolean);

    /// <summary>
    ///   Sets the search paths for source files such as <c>.inc</c> and <c>.pas</c>, which the compiler uses to locate units and include files.
    /// </summary>
    /// <param name="APath">
    ///   A semicolon-separated list of directories to be added to the compiler's search path.
    /// </param>
    /// <remarks>
    ///   - Properly configuring the search path ensures that all necessary source files are found during compilation.
    ///   - This method corresponds to the Free Pascal compiler's <c>-Fu</c> and <c>-Fi</c> command-line options, which set the unit and include file search paths, respectively. :contentReference[oaicite:2]{index=2}
    /// </remarks>
    procedure SetSearchPath(const APath: string);

    /// <summary>
    ///   Retrieves the current console mode setting for the output module.
    /// </summary>
    /// <returns>
    ///   A <c>Boolean</c> indicating whether the output module is configured to have an attached console window.
    /// </returns>
    /// <remarks>
    ///   - A return value of <c>True</c> signifies that the application is set to run as a console application, meaning it will have an attached console window.
    ///   - A return value of <c>False</c> indicates that the application is configured as a GUI application without a console window.
    ///   - This setting is particularly relevant for platforms like Windows, where applications can be designated as either console or GUI types.
    /// </remarks>
    function GetConsoleMode(): Boolean;

    /// <summary>
    ///   Sets the console mode for the output module, determining whether it will have an attached console window.
    /// </summary>
    /// <param name="AConsoleMode">
    ///   A <c>Boolean</c> value where <c>True</c> configures the application to run as a console application with an attached console window, and <c>False</c> configures it as a GUI application without a console window.
    /// </param>
    /// <remarks>
    ///   - On platforms such as Windows, setting this to <c>True</c> ensures the application is treated as a console application, which is essential for applications that perform console input and output operations.
    ///   - Conversely, setting this to <c>False</c> designates the application as a GUI application, which is appropriate for applications with graphical user interfaces.
    ///   - This setting corresponds to the Free Pascal compiler's `-WG` option, which specifies whether to generate a Windows GUI application. :contentReference[oaicite:0]{index=0}
    ///   - Additionally, the `{$APPTYPE GUI}` or `{$APPTYPE CONSOLE}` compiler directives can be used within the source code to specify the application type. :contentReference[oaicite:1]{index=1}
    /// </remarks>
    procedure SetConsoleMode(const AConsoleMode: Boolean);

    /// <summary>
    ///   Compiles the project specified by the current project filename into the designated output type, such as an executable (EXE) or dynamic-link library (DLL).
    /// </summary>
    /// <returns>
    ///   A <c>Boolean</c> value: <c>True</c> if the compilation succeeds without errors; otherwise, <c>False</c>.
    /// </returns>
    /// <remarks>
    ///   - Prior to compilation, this method scans the main project file for a special comment section containing project directives. These directives configure various compilation settings.
    ///   - The directives should be formatted as follows within the source code:
    ///     <code>
    ///     {==================== [PROJECT DIRECTIVES] =================================}
    ///     {@APPTYPE        CONSOLE} // CONSOLE|GUI
    ///     {@OUTPUTPATH     ".\"}
    ///     {.@EXEICON       ".\main.ico"} // remove "." before @, set path to icon
    ///     {@SEARCHPATH     ".\"} // path1;path2;path3 seperated by ";"
    ///     {@BUILDCONFIG    DEBUG} // DEBUG|RELEASE
    ///     {@ADDVERSIONINFO NO} // YES|NO
    ///     {@MAJORVER       1} // valid numerical value 0-n
    ///     {@MINORVER       0} // valid numerical value 0-n
    ///     {@PATCHVER       0} // valid numerical value 0-n
    ///     {@PRODUCTNAME    "Project Name"}
    ///     {@DESCRIPTION    "Your Project"}
    ///     {@COMPANYNAME    "Your Company"}
    ///     {@COPYRIGHT      "Copyright © 2025-present Your Company™"}
    ///     {@TRADEMARK      "All Rights Reserved."}
    ///     {@COMMENT        "http://yourcompany.com"}
    ///     {===========================================================================}
    ///     </code>
    ///     - These directives correspond to various Free Pascal compiler options and settings:
    ///     - <c>{@APPTYPE}</c>: Specifies the application type, such as CONSOLE or GUI. This aligns with the <c>{$APPTYPE}</c> compiler directive. [Compiler Directives - Free Pascal](https://www.freepascal.org/docs-html/prog/progch1.html)
    ///     - <c>{@OUTPUTPATH}</c>: Sets the directory for the compiled output files.
    ///     - <c>{@EXEICON}</c>: Defines the path to the application's icon file.
    ///     - <c>{@SEARCHPATH}</c>: Specifies directories to be added to the compiler's search path for units and include files. This corresponds to the <c>-Fu</c> and <c>-Fi</c> compiler options. [IDE Window: Compiler Options - Free Pascal wiki](https://wiki.freepascal.org/IDE_Window%3A_Compiler_Options)
    ///     - <c>{@BUILDCONFIG}</c>: Determines the build configuration, such as DEBUG or RELEASE.
    ///     - <c>{@ADDVERSIONINFO}</c>: Indicates whether to include version information in the compiled output.
    ///     - <c>{@MAJORVER}</c>, <c>{@MINORVER}</c>, <c>{@PATCHVER}</c>: Define the version numbers for the application.
    ///     - <c>{@DESCRIPTION}</c>, <c>{@COMPANYNAME}</c>, <c>{@COPYRIGHT}</c>, <c>{@TRADEMARK}</c>, <c>{@COMMENT}</c>: Provide metadata about the application, corresponding to compiler directives like <c>{$DESCRIPTION}</c> and <c>{$COPYRIGHT}</c>. [Compiler Directives - Free Pascal](https://www.freepascal.org/docs-html/prog/progch1.html)
    ///   - The method reads these directives from the main project file and applies the specified settings during the compilation process.
    ///   - Ensure that the main project file is correctly set using <c>SetProjectFilename</c> before invoking this method.
    /// </remarks>
    function Compile(): Boolean;

    /// <summary>
    ///   Retrieves the exit code from the last compilation or CLI operation performed by the <c>libFPC</c> instance.
    /// </summary>
    /// <returns>
    ///   A <c>LongWord</c> representing the exit code:
    ///   - <c>0</c> indicates successful execution.
    ///   - Non-zero values indicate various error conditions as defined by the Free Pascal runtime error codes.
    /// </returns>
    /// <remarks>
    ///   - This method provides insight into the result of the last operation, allowing for programmatic error handling and logging.
    ///   - For a comprehensive list of Free Pascal runtime error codes and their meanings, refer to the Free Pascal documentation. [Free Pascal Runtime Error Codes](https://www.freepascal.org/docs-html/user/userap1.html)
    /// </remarks>
    function GetExitCode(): LongWord;

    /// <summary>
    ///   Determines the type of output module generated by the last compilation.
    /// </summary>
    /// <returns>
    ///   A <c>TlfpOutputModual</c> value indicating the output type:
    ///   - <c>omUnknown</c>: The output type is not determined.
    ///   - <c>omEXE</c>: An executable file was generated.
    ///   - <c>omDLL</c>: A dynamic-link library was generated.
    /// </returns>
    /// <remarks>
    ///   - This method allows for verification of the output type produced by the compilation process, ensuring that the generated module matches the expected format.
    ///   - The output type is influenced by project settings and compiler directives specified during the compilation.
    /// </remarks>
    function GetModualType(): TlfpOutputModual;

    /// <summary>
    ///   Retrieves the filename of the output generated by the last compilation.
    /// </summary>
    /// <returns>
    ///   A <c>string</c> containing the full path to the output file.
    /// </returns>
    /// <remarks>
    ///   - This method provides the exact location of the compiled output, which is useful for further processing or execution.
    ///   - The output filename is determined by the project settings and may be influenced by directives such as <c>{@OUTPUTPATH}</c> and the name of the project file.
    ///   - If the output filename is not explicitly set, the compiler may use default naming conventions based on the project filename and output type.
    /// </remarks>
    function GetOutputFilename(): string;

    /// <summary>
    ///   Executes the command-line interface (CLI) version of the <c>libFPC</c> library, processing command-line arguments and initiating the compilation process accordingly.
    /// </summary>
    /// <returns>
    ///   An <c>Integer</c> representing the exit code of the CLI operation.
    /// </returns>
    /// <remarks>
    ///   - This method enables the use of <c>libFPC</c> in a command-line environment, allowing for scriptable and automated compilation workflows.
    ///   - It parses standard command-line arguments to configure compilation settings, such as specifying the project file, output type, and other compiler options.
    ///   - The method returns an exit code that indicates the success or failure of the operation, which can be used for error handling in scripts.
    ///   - For a list of supported command-line arguments and their usage, refer to the <c>libFPC</c> documentation.
    /// </remarks>
    function CLI(): Integer;
  end;

implementation

{ TCompiler }
function TlibFPC.GetDirective(aLine: string; aDirective: string; var aValue: string): Boolean;
var
  LLine: string;
  LDirective: string;
  LValues: TStringList;
  N: Integer;
begin
  Result := False;
  LDirective := aDirective.Trim;
  if not LDirective.StartsWith('@') then Exit;
  LLine := aLine.Trim;
  if LLine.StartsWith('{' + LDirective, True) then
  begin
    LValues := TStringList.Create;
    N := ExtractStrings(['{', '}', ' '], [' '], PChar(LLine), LValues);
    if N >= 2 then
    begin
      aValue := lfpRemoveQuotes(LValues[1]);
      Result := True;
    end;
    lfpFreeNilObject(LValues);
  end;
end;

procedure TlibFPC.ProcessDirectives(const AFilename: string);
var
  LCode: TStringList;
  LLine: string;
  LValue: string;
begin
  if not TFile.Exists(AFilename) then Exit;
  LCode := TStringList.Create;
  LCode.LoadFromFile(AFilename);

  for LLine in LCode do
  begin
    if GetDirective(LLine, '@APPTYPE', LValue) then
      begin
        if SameText('CONSOLE', LValue) then
          FProject.ConsoleApp := True
        else
        if SameText('GUI', LValue) then
          FProject.ConsoleApp := False;
      end
    else

    if GetDirective(LLine, '@OUTPUTPATH', LValue) then
      begin
        FProject.OutputPath := LValue;
      end
    else

    if GetDirective(LLine, '@EXEICON', LValue) then
      begin
        FProject.ExeIconFilename := TPath.GetFullPath(LValue);
      end
    else

    if GetDirective(LLine, '@SEARCHPATH', LValue) then
      begin
        FProject.SearchPath := LValue;
      end
    else

    if GetDirective(LLine, '@BUILDCONFIG', LValue) then
      begin
        if SameText('DEBUG', LValue) then
          FProject.DebugMode := True
        else
        if SameText('RELEASE', LValue) then
          FProject.DebugMode := False
      end
    else

    if GetDirective(LLine, '@ADDVERSIONINFO', LValue) then
      begin
        if SameText('YES', LValue) then
          FProject.AddVersionInfo := True
        else
        if SameText('NO', LValue) then
          FProject.AddVersionInfo := False;
      end
    else

    if GetDirective(LLine, '@MAJORVER', LValue) then
      begin
        FProject.MajorVer := LValue.ToInteger();
      end
    else

    if GetDirective(LLine, '@MINORVER', LValue) then
      begin
        FProject.MinorVer := LValue.ToInteger();
      end
    else

    if GetDirective(LLine, '@PATCHVER', LValue) then
      begin
        FProject.PatchVer := LValue.ToInteger();
      end
    else

    if GetDirective(LLine, '@PRODUCTNAME', LValue) then
      begin
        FProject.ProductName := LValue;
      end
    else

    if GetDirective(LLine, '@DESCRIPTION', LValue) then
      begin
        FProject.Description := LValue;
      end
    else

    if GetDirective(LLine, '@COMPANYNAME', LValue) then
      begin
        FProject.CompanyName := LValue;
      end
    else

    if GetDirective(LLine, '@COPYRIGHT', LValue) then
      begin
        FProject.Copyright := LValue;
      end
    else

    if GetDirective(LLine, '@TRADEMARK', LValue) then
      begin
        FProject.Trademark := LValue;
      end
    else

    if GetDirective(LLine, '@COMMENT', LValue) then
      begin
        FProject.Comment := LValue;
      end
  end;

  lfpFreeNilObject(LCode);
end;

constructor TlibFPC.Create();
begin
  inherited;
  FIsInit := TFile.Exists(lfpGetExeBasePath('ppcx64.exe'));
  FCmdLine := TStringList.Create();
  Reset();
end;

destructor TlibFPC.Destroy;
begin
  FCmdLine.Free();
  inherited;
end;

function  TlibFPC.GetVersion(): string;
begin
  Result := '0.1.0';
end;

procedure TlibFPC.Reset();
begin
  FCacheDir := TPath.Combine(lfpGetEXEPath(), 'cache');
  FOutputFilename := '';
  FModualType := omUnknown;
  FProject.MajorVer := 1;
  FProject.MinorVer := 0;
  FProject.PatchVer := 0;
  FProject.ProductName := 'Your Project Name';
  FProject.Description := 'Your Product Description';
  FProject.CompanyName := 'Your Company Name';
  FProject.Copyright := 'Copyright (c) 2025';
  FProject.Trademark := 'All Rights Reserved.';
  FProject.Comment := 'Your Comments';

  CleanCmdLine();
  ClearCache();
end;

function  TlibFPC.IsInit(): Boolean;
begin
  Result := FIsInit;
end;

function  TlibFPC.GetPrintEvent(): TlfpPrintEvent;
begin
  Result := FEvents.Print.Handler;
end;

procedure TlibFPC.SetPrintEvent(const AHandler: TlfpPrintEvent; const AUserData: Pointer);
begin
  FEvents.Print.UserData := AUserData;
  FEvents.Print.Handler := AHandler;
end;

procedure TlibFPC.SetProjectFilename(const AFilename: string);
begin
  FProject.Filename := TPath.ChangeExtension(AFilename, 'pas');
end;

function  TlibFPC.GetProjectFilename(): string;
begin
  Result := FProject.Filename;
end;

procedure TlibFPC.SetOutputPath(const APath: string);
begin
  FProject.OutputPath := APath;
end;

procedure TlibFPC.SetDebugMode(const AEnable: Boolean);
begin
  FProject.DebugMode := AEnable;
end;

procedure TlibFPC.SetSearchPath(const APath: string);
begin
  FProject.SearchPath := APath;
end;

procedure TlibFPC.Print(const AMsg: string; const AArgs: array of const);
var
  LText: string;
begin
  LText := Format(AMsg, AArgs);

  if Assigned(FEvents.Print.Handler) then
    begin
      FEvents.Print.Handler(LText, FEvents.Print.UserData);
    end
  else
    begin
      if lfpHasConsoleOutput() then
        Write(LText);
    end;
end;

procedure TlibFPC.PrintLn(const AMsg: string; const AArgs: array of const);
begin
  Print(AMsg+#10#13, AArgs);
end;

procedure TlibFPC.Header();
begin
  PrintLn('', []);
  PrintLn('libFPC™ Commandline Compiler v%s', [GetVersion()]);
  PrintLn('Copyright © 2024-present tinyBigGAMES™ LLC', []);
  PrintLn('All Rights Reserved.', []);
  PrintLn('', []);
end;

procedure TlibFPC.Usage();
begin
  PrintLn('Usage:', []);
  PrintLn('  lfpc <filename> - project sourcefile', []);
  PrintLn('', []);
  PrintLn('  lfpc <command>', []);
  PrintLn('      -exe=<filename> - Create EXE project file', []);
  PrintLn('      -dll=<filename> - Create DLL project file', []);
  PrintLn('      -unit=<filename> - Create UNIT source file', []);
  PrintLn('      --help - Show this help screen', []);
end;

procedure TCompiler_OnConsoleEvent(const ASender: Pointer; const ALine: string);
begin
  if Assigned(ASender) then
    TlibFPC(ASender).OnCaptureConsole(ALine);
end;

procedure TlibFPC.OnCaptureConsole(const ALine: string);
begin
  if ContainsText(aLine, 'windres.exe') or
     ContainsText(aLine, 'cpp.exe')     or
     ContainsText(aLine, 'fpcres.exe')  or
     ContainsText(aLine, 'Target OS')  or
     ContainsText(aLine, 'note(s)') then
    Exit;

  if ALine.Trim.StartsWith('linking', True) then
  begin
    FOutputFilename := TPath.GetFullPath(ALine.Replace('Linking', '').Trim);
  end;

  PrintLn(ALine, []);
end;

function TlibFPC.GetCmdLine(): string;
var
  S: string;
begin
  Result := '';
  for S in FCmdLine do
  begin
    Result := Result + s + ' ';
  end;
  Result := Result.Trim;
end;

procedure TlibFPC.CleanCmdLine();
begin
  FCmdLine.Clear();
end;

procedure TlibFPC.ClearCache();
begin
  lfpEmptyFolder(FCacheDir);
end;

procedure TlibFPC.AddToCmdLine(const AMsg: string; const AArgs: array of const);
begin
  FCmdLine.Add(Format(AMsg, AArgs));
end;

function  TlibFPC.GetConsoleMode(): Boolean;
begin
  Result := FProject.ConsoleApp;
end;

procedure TlibFPC.SetConsoleMode(const AConsoleMode: Boolean);
begin
  FProject.ConsoleApp := AConsoleMode;
end;

function TlibFPC.Compile(): Boolean;
var
  LCmd: string;
  LDir: TlfpDirectoryStack;
  LProjectFilename: string;
  LOutputPath: string;
  LExt: string;
  LPath: string;
begin
  Result := False;
  if FProject.Filename.IsEmpty then Exit;

  Reset();
  CleanCmdLine();

  // get full path to project filename
  LProjectFilename := TPath.GetFullPath(FProject.Filename);

  LDir := TlfpDirectoryStack.Create();
  try
    // process directives
    ProcessDirectives(LProjectFilename);
    //SetVersionNumber(FProject.MajorVer, FProject.MinorVer, FProject.PatchVer);
    //SetVersionInfo(FProject.Description, FProject.CompanyName, FProject.Copyright, FProject.Trademark, FProject.Comment);

    // add comiler
    AddToCmdLine('"%s"', [lfpGetExeBasePath(CCompilerPath)]);

    // add project file
    AddtoCmdLine('%s', [LProjectFilename]);

    // add default command line
    AddToCmdLine(CDefCmdLine, []);

    // init unit output path
    AddToCmdLine('-FU"%s"', [FCacheDir]);

    // output path
    LOutputPath := FProject.OutputPath;
    if not LOutputPath.IsEmpty then
    begin
      if TPath.IsRelativePath(LOutputPath) then
        LOutputPath := lfpExpandRelFilename(LProjectFilename, LOutputPath);
      AddToCmdLine('-FE"%s"', [LOutputPath]);
      TDirectory.CreateDirectory(LOutputPath);
    end;

    // search path
    LPath := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), '..\lib');
    LPath := TPath.GetFullPath(LPath);
    //if not Utils.ContainsText(FProject.SearchPath, ';..\lib') then
    //  FProject.SearchPath := FProject.SearchPath + '";..\lib"';
    FProject.SearchPath := FProject.SearchPath + ';' + LPath;

    if not FProject.SearchPath.IsEmpty then
    begin
      AddToCmdLine('-Fu"%s"', [FProject.SearchPath]);
      AddToCmdLine('-Fi"%s"', [FProject.SearchPath]);
      AddToCmdLine('-Fl"%s"', [FProject.SearchPath]);
    end;

    // console app
    if FProject.ConsoleApp then
      AddToCmdLine('-WC', [])
    else
      AddToCmdLine('-WC-', []);

    AddToCmdLine('-B', []);

    // debug mode
    if FProject.DebugMode then
      begin
        AddToCmdLine('-g', []);           // debug info
        AddToCmdLine('-dDEBUG', []);      // define debug symbol
        AddToCmdLine('-gh', []);          // debug heaptrace
        AddToCmdLine('-gl', []);          // debug lineinfo
        AddToCmdLine('-WN', []);          // dont generate relocation image
        AddToCmdLine('-dHEAPTRACE', []);  // define heaptrace symbol
        PrintLn('Debug mode enabled...', []);
      end
    else
      begin
        AddToCmdLine('-Xs', []);          // strip symbols
        AddToCmdLine('-WB', []);          // generate relocatable image
        AddToCmdLine('-dRELEASE', []);    // define release symbol
        //AddToCmdLine('-OoreGvar', []);    // peephole optimizations
        PrintLn('Release mode enabled...', []);
      end;

    LCmd := GetCmdLine();

    LDir.PushFilePath(LProjectFilename);
    try
      FExitCode := 0;
      FOutputFilename := '';
      lfpCaptureConsoleOutput('libFPC', PChar(LCmd), nil, FExitCode, Self, TCompiler_OnConsoleEvent);
    finally
      LDir.Pop();
    end;

    // process outputfilename
    if FExitCode = 0 then
    begin
      if not FOutputFilename.IsEmpty then
        begin
          Result := TFile.Exists(FOutputFilename);
          if Result then
          begin
            LExt := TPath.GetExtension(FOutputFilename).ToLower;
            if SameText(LExt, '.exe') then
              FModualType := omEXE
            else
            if SameText(LExt, '.dll') then
              FModualType := omDLL;

            // set version info here
            UpdateManifest();
            UpdatePayloadIcon();
            if FProject.AddVersionInfo then
              UpdatePayloadVersionInfo();
          end;
        end
      else
        begin
          if FExitCode = 0 then
            Result := True;
        end;
      end;
  finally
    LDir.Free();
  end;
end;

function  TlibFPC.GetExitCode(): DWORD;
begin
  Result := FExitCode;
end;

function  TlibFPC.GetModualType(): TlfpOutputModual;
begin
  Result := FModualType;
end;

function  TlibFPC.GetOutputFilename(): string;
begin
  Result := FOutputFilename;
end;

function TlibFPC.UpdateManifest(): Boolean;
begin
  Result := False;
  if FModualType <> omEXE then Exit;
  if not TFile.Exists(FOutputFilename) then Exit;
  Result := lfpAddResManifestFromResource('a439e025cc1f4759a38224d6175931b6', FOutputFilename)
end;

function TlibFPC.UpdatePayloadIcon(): Boolean;
begin
  Result := False;
  if FModualType <> omEXE then Exit;
  if not TFile.Exists(FOutputFilename) then Exit;
  if not TFile.Exists(FProject.ExeIconFilename) then Exit;
  if not lfpIsValidWin64PE(FOutputFilename) then Exit;
  lfpUpdateIconResource(FOutputFilename, FProject.ExeIconFilename);
  Result := True;
end;

function TlibFPC.UpdatePayloadVersionInfo(): Boolean;
begin
  Result := False;
  if not TFile.Exists(FOutputFilename) then Exit;
  if not lfpIsValidWin64PE(FOutputFilename) then Exit;
  lfpUpdateVersionInfoResource(FOutputFilename, FProject.MajorVer, FProject.MinorVer, FProject.PatchVer, FProject.ProductName,
    FProject.Description, TPath.GetFileName(FOutputFilename), FProject.CompanyName, FProject.Copyright);
  Result := True;
end;

function TlibFPC.GenerateSource(const AType: TSourceType; var AOutputFilename: string): Boolean;
const
  CProjectDirectives =
  '''
  {==================== [PROJECT DIRECTIVES] =================================}
  {@APPTYPE        CONSOLE} // CONSOLE|GUI
  {@OUTPUTPATH     ".\"}
  {.@EXEICON       ".\main.ico"} // remove "." before @, set path to icon
  {@SEARCHPATH     ".\"} // path1;path2;path3 seperated by ";"
  {@BUILDCONFIG    DEBUG} // DEBUG|RELEASE
  {@ADDVERSIONINFO NO} // YES|NO
  {@MAJORVER       1} // valid numerical value 0-n
  {@MINORVER       0} // valid numerical value 0-n
  {@PATCHVER       0} // valid numerical value 0-n
  {@PRODUCTNAME    "Project Name"}
  {@DESCRIPTION    "Your Project"}
  {@COMPANYNAME    "Your Company"}
  {@COPYRIGHT      "Copyright © 2025-present Your Company™"}
  {@TRADEMARK      "All Rights Reserved."}
  {@COMMENT        "http://yourcompany.com"}
  {===========================================================================}
  ''';

  CEXETemplate =
  '''
  %directives%

  program %name%;

  uses
    sysutils,
    windows;

  begin
    // insert your code

  end.
  ''';

  CDLLTemplate =
  '''
  %directives%

  library %name%;

  uses
    sysutils,
    windows;

  // insert your code

  end.
  ''';

  CUnitTemplate =
  '''
  unit %name%;

  interface

  uses
    sysutils,
    windows;

  // insert your unit interface code here

  implementation

  // insert your unit implementation code here

  initialization

  // insert your unit initialization code here

  finalization

  // insert your unit finalization code here

  end.
  ''';

var
  LCode: TStringList;

  procedure C(const AMsg: string; const AArgs: array of const);
  begin
    LCode.Add(Format(AMsg, AArgs));
  end;

  procedure B();
  begin
    LCode.Add('');
  end;

  procedure ProcessTemplate();
  var
    LName: string;
  begin
    LName := TPath.GetFileNameWithoutExtension(AOutputFilename);

    LCode.Text := LCode.Text.Replace('%directives%', CProjectDirectives);
    LCode.Text := LCode.Text.Replace('%name%', LName);

    LCode.SaveToFile(AOutputFilename, TEncoding.UTF8);
  end;

begin
  Result := False;
  if AOutputFilename.IsEmpty then Exit;

  AOutputFilename := TPath.ChangeExtension(TPath.GetFullPath(AOutputFilename), 'pas');

  if TFile.Exists(AOutputFilename) then
  begin
    PrintLn('Sourcefile already exist: "%s"', [AOutputFilename]);
    Exit;
  end;

  try
    LCode := TStringList.Create();
    try

      case AType of
        stEXE:
        begin
          LCode.Text := CEXETemplate;
          ProcessTemplate();
          Result := True;
        end;

        stDLL:
        begin
          LCode.Text := CDLLTemplate;
          ProcessTemplate();
          Result := True;
        end;

        stUnit:
        begin
          LCode.Text := CUnitTemplate;
          ProcessTemplate();
          Result := True;
        end;
      end;

    finally
      LCode.Free();
    end;
  except
    on E: Exception do
    begin
      PrintLn(E.Message, []);
    end;
  end;

end;

function TlibFPC.CLI(): Integer;
var
  LValue: string;
begin
  Result := 0;
  Header();

  // reset commandline
  TlfpCmdLine.Reset();

  // check for help
  if TlfpCmdLine.GetParam('-help') then
  begin
    Usage();
    Exit;
  end;

  // process create exe source file
  if TlfpCmdLine.GetParamValue('exe', LValue) then
  begin
    if GenerateSource(stEXE, LValue) then
      PrintLn('Created EXE sourcefile: "%s"', [LValue]);
    Exit;
  end;

  // process create dll source file
  if TlfpCmdLine.GetParamValue('dll', LValue) then
  begin
    if GenerateSource(stDLL, LValue) then
      PrintLn('Created DLL sourcefile: "%s"', [LValue]);
    Exit;
  end;

    // process create unit source file
  if TlfpCmdLine.GetParamValue('unit', LValue) then
  begin
    if GenerateSource(stUNIT, LValue) then
      PrintLn('Created UNIT sourcefile: "%s"', [LValue]);
    Exit;
  end;

  // process project name
  if not TlfpCmdLine.GetParamValue('', LValue) then
  begin
    Usage();
    Exit;
  end;

  SetProjectFilename(LValue);
  if Compile() then
    begin
      PrintLn('Success!', []);
      Result := 0;
    end
  else
    begin
      PrintLn('Failed!', []);
      Result := 1;
    end;
end;

//===========================================================================

{$R libFPC.res}

var
  CLibsDLLHandle: THandle = 0;
  CLibsDLLFilename: string = '';

function HasEnoughDiskSpace(const AFilePath: string; ARequiredSize: Int64): Boolean;
var
  LFreeAvailable, LTotalSpace, LTotalFree: Int64;
  LDrive: string;
begin
  Result := False;

  // Resolve the absolute path in case of a relative path
  LDrive := ExtractFileDrive(TPath.GetFullPath(AFilePath));

  // If there is no drive letter, use the current drive
  if LDrive = '' then
    LDrive := ExtractFileDrive(TDirectory.GetCurrentDirectory);

  // Ensure drive has a trailing backslash
  if LDrive <> '' then
    LDrive := LDrive + '\';

  if GetDiskFreeSpaceEx(PChar(LDrive), LFreeAvailable, LTotalSpace, @LTotalFree) then
    Result := LFreeAvailable >= ARequiredSize;
end;

function LoadClibsDLL(var AError: string): Boolean;
var
  LResStream: TResourceStream;

  function df967db2378b4df5b748f7c2c52f4963(): string;
  const
    CValue = '89173d23d1e84a77b080853d9ae09400';
  begin
    Result := CValue;
  end;

  procedure SetError(const AText: string; const AArgs: array of const);
  begin
    AError := Format(AText, AArgs);
  end;

begin
  Result := False;
  AError := '';

  // load deps DLL
  if CLibsDLLHandle <> 0 then Exit;
  try
    if not Boolean((FindResource(HInstance, PChar(df967db2378b4df5b748f7c2c52f4963()), RT_RCDATA) <> 0)) then
    begin
      SetError('Failed to find CLibs DLL resource', []);
      Exit;
    end;

    LResStream := TResourceStream.Create(HInstance, df967db2378b4df5b748f7c2c52f4963(), RT_RCDATA);
    try
      LResStream.Position := 0;
      CLibsDLLFilename := TPath.Combine(TPath.GetTempPath, TPath.ChangeExtension(TPath.GetGUIDFileName.ToLower, '.'));

      if not HasEnoughDiskSpace(CLibsDLLFilename, LResStream.Size) then
      begin
        SetError('Not enough disk space to save extracted CLibs DLL', []);
        Exit;
      end;

      LResStream.SaveToFile(CLibsDLLFilename);

      if not TFile.Exists(CLibsDLLFilename) then
      begin
        SetError('Failed to find extracted CLibs DLL', []);
        Exit;
      end;

      CLibsDLLHandle := LoadLibrary(PChar(CLibsDLLFilename));
      if CLibsDLLHandle = 0 then
      begin
        SetError('Failed to load extracted CLibs DLL', []);
        Exit;
      end;

      Result := True;
    finally
      LResStream.Free();
    end;

  except
    on E: Exception do
      SetError('Unexpected error: %s', [E.Message]);
  end;
end;

procedure UnloadCLibsDLL();
begin
  // unload CLibs DLL
  if CLibsDLLHandle <> 0 then
  begin
    FreeLibrary(CLibsDLLHandle);
    TFile.Delete(CLibsDLLFilename);
    CLibsDLLHandle := 0;
    CLibsDLLFilename := '';
  end;
end;

initialization
var
  LError: string;
begin
  ReportMemoryLeaksOnShutdown := True;
  SetExceptionMask(GetExceptionMask + [exOverflow, exInvalidOp]);
  SetConsoleCP(CP_UTF8);
  SetConsoleOutputCP(CP_UTF8);
  lfpEnableVirtualTerminalProcessing();
  Randomize();

  TlfpCmdLine.Reset();

  SetExceptionMask(GetExceptionMask + [exOverflow, exInvalidOp]);

  if not LoadClibsDLL(LError) then
  begin
    MessageBox(0, PChar(LError), 'Critical Initialization Error', MB_ICONERROR);
    Halt(1); // Exit the application with a non-zero exit code to indicate failure
  end;
end;

finalization
begin
  try
    UnloadCLibsDLL();
  except
    on E: Exception do
    begin
      MessageBox(0, PChar(E.Message), 'Critical Shutdown Error', MB_ICONERROR);
    end;
  end;
end;


end.
