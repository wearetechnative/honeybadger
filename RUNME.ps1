echo "NEW REPORT" > audit-report.txt

mkdir report
$bitlocker_outfile = ".\report\bitlocker_result.txt"
$code = "Get-BitLockerVolume 2>&1 | Out-File -FilePath `"$bitlocker_outfile`" -Encoding utf8 -Append"

$prog = "powershell.exe"

# Pass the code as argument for -Command, en geef het outputpad mee als $o
Invoke-Command -ScriptBlock { param($p,$a,$o)
    # Start elevated PowerShell die de expressie ($a) uitvoert
    Start-Process $p -ArgumentList @('-NoProfile','-Command',$a) -Wait -Verb RunAs
    Get-Content $o
} -ArgumentList $prog,$code,$bitlocker_outfile

Import-Module .\HardeningKitty\HardeningKitty.psm1
Invoke-HardeningKitty -Mode Config -Report -ReportFile .\report\hardeningkitty.csv
