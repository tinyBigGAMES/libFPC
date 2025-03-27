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

program Testbed;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  libFPC in '..\..\src\libFPC.pas',
  UTestbed in 'UTestbed.pas',
  libFPC.Utils in '..\..\src\libFPC.Utils.pas';

begin
  try
    RunTests();
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
