echo "NEW REPORT" > audit-report.txt

mkdir report
$bitlocker_outfile = ".\report\bitlocker_result.txt"
$code = "Get-BitLockerVolume 2>&1 >>$bitlocker_outfile"

$prog = "powershell.exe"
Invoke-Command  -ScriptBlock { param($p,$a,$o)
                                                            Start-Process $p -ArgumentList $a -wait -verb RunAs
                                                            get-content $o
                                                        } -ArgumentList $prog,$code,$output

Import-Module .\HardeningKitty\HardeningKitty.psm1

Invoke-HardeningKitty -Mode Config -Report -ReportFile .\report\hardeningkitty.csv
