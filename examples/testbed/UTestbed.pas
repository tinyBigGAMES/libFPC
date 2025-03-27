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

unit UTestbed;

interface

uses
  System.SysUtils,
  libFPC;

procedure RunTests();

implementation

(*=============================================================================
  Pause: Console Pause Helper
  This procedure introduces a simple pause in console applications, prompting
  the user to press ENTER before continuing execution.

  Behavior:
  - Outputs a blank line for visual spacing.
  - Displays the message "Press ENTER to continue..." without advancing the line.
  - Waits for the user to press ENTER using ReadLn.
  - Adds another blank line after user input for clean separation.

  Steps performed:
  - WriteLn adds an empty line above the prompt.
  - Write displays the message without a line break.
  - ReadLn waits for the user to press ENTER.
  - WriteLn adds another empty line after input is received.

  NOTE: Useful in demos or test routines to allow the user to view output before
        proceeding to the next step.
==============================================================================*)
procedure Pause();
begin
  // Output a blank line for spacing
  WriteLn;

  // Prompt the user to press ENTER without a line break
  Write('Press ENTER to continue...');

  // Wait for the user to press ENTER
  ReadLn;

  // Output another blank line after the pause
  WriteLn;
end;

(*=============================================================================
  Test01: Invoke the libFPC Command-Line Interface
  This procedure demonstrates the most basic use of the TlibFPC class by
  invoking its built-in CLI method. It shows how to instantiate the class
  and access the runtime FreePascal compiler interface via command-line mode.

  Expected Behavior:
  - The CLI output is displayed in the console, offering access to libFPC's
    available options and usage help.

  Steps performed:
  - A TlibFPC instance is created.
  - The CLI method is called to display help or perform a CLI action.
  - The instance is released to free resources.

  NOTE: This is a minimal integration example that verifies correct creation
        and operation of the TlibFPC class. Ideal as a starting point or
        sanity check during development.
==============================================================================*)
procedure Test01();
var
  LlibFPC: TlibFPC;
begin
  // Create an instance of TlibFPC
  LlibFPC := TlibFPC.Create();
  try
    // Invoke the CLI method to show command-line help or perform CLI action
    LlibFPC.CLI();
  finally
    // Free the instance to release memory and resources
    LlibFPC.Free();
  end;
end;

(*=============================================================================
  Test02: Compile a Pascal Source File
  This procedure demonstrates how to compile a Pascal source file using the
  TlibFPC class. It sets a project filename and calls the Compile method,
  printing the result to the console.

  Expected Behavior:
  - If the file compiles successfully, "Success!" is printed.
  - If the compilation fails, "Failed!" is printed instead.

  Steps performed:
  - A TlibFPC instance is created.
  - The filename 'test1.pas' is assigned via SetProjectFilename.
  - The Compile method is invoked.
  - The result is displayed using WriteLn.
  - The instance is released at the end.

  NOTE: This example assumes that 'test1.pas' exists in the current working
        directory or with a valid path accessible by the compiler.
==============================================================================*)
procedure Test02();
var
  LlibFPC: TLibFPC;
begin
  // Create an instance of TLibFPC
  LlibFPC := TLibFPC.Create();
  try
    // Assign the Pascal source file to compile
    LlibFPC.SetProjectFilename('test1.pas');

    // Compile the file and display the result
    if LlibFPC.Compile() then
      WriteLn('Success!')             // Print success message if compilation passed
    else
      WriteLn('Failed!');             // Print failure message otherwise
  finally
    // Free the instance to release resources
    LlibFPC.Free();
  end;

  Pause();
end;

(*=============================================================================
  RunTests: Execute a Specific Test Procedure
  This procedure selects and runs a test case based on the value of a local
  integer variable. It demonstrates a basic test harness pattern using a
  hardcoded test selector.

  Behavior:
  - Sets LNum to 02, causing Test02 to be executed.
  - Uses a case statement to dispatch the corresponding test procedure.
  - Calls Pause afterward to wait for user input before continuing.

  Steps performed:
  - Declare and initialize the test selector variable (LNum).
  - Use a case statement to invoke the appropriate test.
  - Pause execution for user interaction.

  NOTE: This pattern is useful for running isolated test cases manually during
        development. To run other tests, change the value of LNum.
==============================================================================*)
procedure RunTests();
var
  LNum: Integer;
begin
  LNum := 01;                         // Set the test number to execute

  case LNum of
    01: Test01();                     // Run Test01
    02: Test02();                     // Run Test02
  end;

end;

end.
