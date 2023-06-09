##PC Info Readme



 ![243457642-ba5943a6-8520-4300-b1fd-6ef768f10b56](https://github.com/ITAutomator/PCInfo/assets/135157036/944be711-5fb2-4f79-bee6-504ac1f394b5)

## Overview <br>
Run as user (not as admin)<br>
Shows all kinds of useful information about the PC and User

To Run<br>
Press _Windows-R_ (Run) and paste: <br>
__powershell -executionpolicy bypass Invoke-Expression (Invoke-WebRequest https://raw.githubusercontent.com/ITAutomator/pcinfo/main/PC%20Info.ps1).Content__

Open Powershell and paste<br>
__Invoke-Expression ((Invoke-WebRequest https://raw.githubusercontent.com/ITAutomator/pcinfo/main/PC%20Info.ps1).Content)__

Download Ps1 and run

Download from here: PC Info.ps1

Information Returned <br>
Fast Boot <br>
Most IT pros think this should be 0 Off. Windows is 1 On by default. <br>
If Fast Boot is on for a computer, it means that shut down is the same as hibernation. In this case a shut down is not as good as a restart for applying updates etc. <br>
Turn this off to go back to a slower but safer shutdown.  The speed benefit is negligible anyway if an SSD is installed. <br>
Note: The Setup Windows System package turns off Fast Boot <br>
To turn off fast startup (hiberbootenabled) manually <br>
Note: This is a system setting and will require admin access to change. <br>
Press Win+R > "control" > "power buttons" > Turn on fast startup [Untick this box] <br>

Notifications <br>
Most IT pros think this should be 1.<br>
If this is 0, it means that the user has opted out from all system notifications, regardless of source.

