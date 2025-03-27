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

{$WARN SYMBOL_DEPRECATED OFF}
{$WARN SYMBOL_PLATFORM OFF}

{$WARN UNIT_PLATFORM OFF}
{$WARN UNIT_DEPRECATED OFF}

{$Z4}
{$A8}

{$INLINE AUTO}

{$IFNDEF WIN64}
  {$MESSAGE Error 'Unsupported platform'}
{$ENDIF}

{$IF (CompilerVersion < 36.0)}
  {$IFNDEF WIN64}
    {$MESSAGE Error 'Must use Delphi 12 or higher'}
  {$ENDIF}
{$IFEND}
