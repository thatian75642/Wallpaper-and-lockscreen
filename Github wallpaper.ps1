<# Set WallPaper
Gary Blok @gwblok Recast Software

Used with OSDCloud Edition OSD

Replaces Default Windows WallPaper with your own

#>


$ScriptVersion = "22.3.8.1"

function enable-privilege {
 param(
  ## The privilege to adjust. This set is taken from
  ## http://msdn.microsoft.com/en-us/library/bb530716(VS.85).aspx
  [ValidateSet(
   "SeAssignPrimaryTokenPrivilege", "SeAuditPrivilege", "SeBackupPrivilege",
   "SeChangeNotifyPrivilege", "SeCreateGlobalPrivilege", "SeCreatePagefilePrivilege",
   "SeCreatePermanentPrivilege", "SeCreateSymbolicLinkPrivilege", "SeCreateTokenPrivilege",
   "SeDebugPrivilege", "SeEnableDelegationPrivilege", "SeImpersonatePrivilege", "SeIncreaseBasePriorityPrivilege",
   "SeIncreaseQuotaPrivilege", "SeIncreaseWorkingSetPrivilege", "SeLoadDriverPrivilege",
   "SeLockMemoryPrivilege", "SeMachineAccountPrivilege", "SeManageVolumePrivilege",
   "SeProfileSingleProcessPrivilege", "SeRelabelPrivilege", "SeRemoteShutdownPrivilege",
   "SeRestorePrivilege", "SeSecurityPrivilege", "SeShutdownPrivilege", "SeSyncAgentPrivilege",
   "SeSystemEnvironmentPrivilege", "SeSystemProfilePrivilege", "SeSystemtimePrivilege",
   "SeTakeOwnershipPrivilege", "SeTcbPrivilege", "SeTimeZonePrivilege", "SeTrustedCredManAccessPrivilege",
   "SeUndockPrivilege", "SeUnsolicitedInputPrivilege")]
  $Privilege,
  ## The process on which to adjust the privilege. Defaults to the current process.
  $ProcessId = $pid,
  ## Switch to disable the privilege, rather than enable it.
  [Switch] $Disable
 )

 ## Taken from P/Invoke.NET with minor adjustments.
 $definition = @'
 using System;
 using System.Runtime.InteropServices;
  
 public class AdjPriv
 {
  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
   ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
  
  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
  [DllImport("advapi32.dll", SetLastError = true)]
  internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  internal struct TokPriv1Luid
  {
   public int Count;
   public long Luid;
   public int Attr;
  }
  
  internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
  internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
  internal const int TOKEN_QUERY = 0x00000008;
  internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
  public static bool EnablePrivilege(long processHandle, string privilege, bool disable)
  {
   bool retVal;
   TokPriv1Luid tp;
   IntPtr hproc = new IntPtr(processHandle);
   IntPtr htok = IntPtr.Zero;
   retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
   tp.Count = 1;
   tp.Luid = 0;
   if(disable)
   {
    tp.Attr = SE_PRIVILEGE_DISABLED;
   }
   else
   {
    tp.Attr = SE_PRIVILEGE_ENABLED;
   }
   retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
   retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
   return retVal;
  }
 }
'@

 $processHandle = (Get-Process -id $ProcessId).Handle
 $type = Add-Type $definition -PassThru
 $type[0]::EnablePrivilege($processHandle, $Privilege, $Disable)
}

function Set-Owner{

Param (
    [Parameter(Mandatory=$true)][string] $identity,
    [Parameter(Mandatory=$true)][String] $filepath
      )

$file = Get-Item -Path $filepath
$acl = $file.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)
$me = [System.Security.Principal.NTAccount]$identity
$acl.SetOwner($me)
$file.SetAccessControl($acl)

# After you have set owner you need to get the acl with the perms so you can modify it.
$acl = $file.GetAccessControl()
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity,"FullControl","Allow")
$acl.SetAccessRule($rule)
$file.SetAccessControl($acl)
#$file.Close()
}

function Set-Permission{

Param (
    [Parameter(Mandatory=$true)][string] $identity,
    [Parameter(Mandatory=$true)][String] $filepath,
    [Parameter(Mandatory=$true)][string] $FilesSystemRights,
    [Parameter(Mandatory=$true)][String] $type
      )
$newacl = $file.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)

# Create new rule
$FilesSystemAccessRuleArgumentList = $identity, $FilesSystemRights, $type
$FilesSystemAccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $FilesSystemAccessRuleArgumentList
# Apply new rule
$NewAcl.SetAccessRule($FilesSystemAccessRule)
Set-Acl -Path $file.FullName -AclObject $NewAcl
}


$files = Get-ChildItem -Path C:\Windows\Web\4K -Recurse | where-object {$_.Extension -eq ".jpg"}

try {$tsenv = new-object -comobject Microsoft.SMS.TSEnvironment}
catch{Write-Output "Not in TS"}
if ($tsenv){$InWinPE = $tsenv.value('_SMSTSInWinPE')}
    


if ($InWinPE -ne "TRUE"){

#Take OwnerShip
enable-privilege SeTakeOwnershipPrivilege 
#Set Permissions on Files
$identity = "BUILTIN\Administrators"
foreach ($filechild in $files)
    {
    Set-Owner -identity $identity -filepath $filechild.fullname
    }

#Grant Rights to Admin & System
# Set Adminstrators of Full Control of File

$identity = "BUILTIN\Administrators"
$FilesSystemRights = "FullControl"
$type = "Allow"
foreach ($filechild in $files)
    {
    Set-Permission -identity $identity -type $type -FilesSystemRights $FilesSystemRights -filepath $filechild.fullname
    }

# Set SYSTEM to Full Control of Registry Item
$identity = "NT AUTHORITY\SYSTEM"
$FilesSystemRights = "FullControl"
$type = "Allow"
foreach ($filechild in $files)
    {
    Set-Permission -identity $identity -type $type -FilesSystemRights $FilesSystemRights -filepath $filechild.fullname
    }

#Delete "4K" images
}

foreach ($filechild in $files)
    {
    remove-item -Path $filechild.fullname -Force -Verbose
    Write-Output "Deleting $($filechild.fullname)"
    }


#Download WallPaper from GitHub
$WallPaperURL = "https://user-images.githubusercontent.com/54353503/174236228-0bc4e44a-8eec-43d0-8622-7da6925abd91.jpg"
Invoke-WebRequest -UseBasicParsing -Uri $WallPaperURL -OutFile "$env:TEMP\wallpaper.jpg"

#Download WallPaper from GitHub
$DarkWallPaperURL = "https://user-images.githubusercontent.com/54353503/174236241-9a1313a1-46d6-4fcc-96e7-d6f412b8512f.jpg"
Invoke-WebRequest -UseBasicParsing -Uri $DarkWallPaperURL -OutFile "$env:TEMP\Darkmodewallpaper.jpg"

#Copy the 2 files into place
if (Test-Path -Path "$env:TEMP\wallpaper.jpg"){
    Write-Output "Running Command: Copy-Item .\wallpaper.jpg C:\Windows\Web\Wallpaper\Windows\img0.jpg -Force -Verbose"
    Copy-Item "$env:TEMP\wallpaper.jpg" "C:\Windows\Web\Wallpaper\Windows\img0.jpg" -Force -Verbose
    Copy-Item "$env:TEMP\Darkmodewallpaper.jpg" "C:\Windows\Web\Wallpaper\Windows\img19.jpg" -Force -Verbose
    Copy-Item "$env:TEMP\Darkmodewallpaper.jpg" "C:\Windows\Web\Wallpaper\Theme1\img19.jpg" -Force -Verbose
    }
else
    {
    Write-Output "Did not find wallpaper.jpg in temp folder - Please confirm URL"
    }


exit $exitcode
