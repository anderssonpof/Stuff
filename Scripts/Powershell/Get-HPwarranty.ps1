#Purpose: Check Warranty Information for HP Computers and write the information to the AD computer object as well as the registry of the computer
#Usage: .\Get-HPwarranty.ps1 computername
#Date: July 14th 2014
#This script is provided "AS IS" with no warranties
#This script will only work as long as HP doesn't change their site

PARAM(
$ComputerName
)

$ComputerName = $ComputerName;
$File = "C:\Temp\script lab\loop\log.txt";
Import-Module ActiveDirectory;

if (Test-Connection $ComputerName -count 1 -quiet) {

try {

	if (get-adcomputer $ComputerName -property SerialNumber| Select-object serialNumber | Where-Object {$_.serialNumber -ne $null}) {
	
	Write-host $ComputerName " already have warranty information";
	}
	
	else {
	
	Write-host $ComputerName;
		
	$table = @(); 
	$serialnumber = (Get-wmiobject -computername $ComputerName -ErrorAction Stop win32_bios).serialnumber;
	$manufacturer = (Get-wmiobject -computername $ComputerName -ErrorAction Stop win32_bios).Manufacturer;
	$model = (get-wmiobject -computername $ComputerName -ErrorAction Stop win32_computersystem).Model;
	$productId =  get-wmiobject -computername $ComputerName -ErrorAction Stop -namespace root\wmi MS_SystemInformation | select -expand systemsku;
	$webService = "http://h10025.www1.hp.com/ewfrf/wc/weResults";
	$parameters = "lc=en&dlc=en&cc=th&tmp_weCountry=us&tmp_weSerial="+ $serialnumber +"&tmp_weProduct="+ $productId;
	
	$site = $webService+ "?" +$parameters;
	
	#Access the web page and find the warranty information
	$result = Invoke-WebRequest $site;
	
	#Parse the web page find the table
	$table = $result.ParsedHtml.getElementsByTagName("td") | where "classname" -match "bottomSpaceBig" | Select -ExpandProperty InnerText;
	$warrantytd = $table[9];
	$warranty = $warrantytd -split " ";
	
	Write-host "Writing warranty information...";
	
	#Write the serial number and date to the AD computer object (serialNumber attribute)
	set-adcomputer $ComputerName -add @{serialNumber = $serialnumber + ", " + $warranty[0]}; 
	
	#Writing information to the registry 
	$type = [Microsoft.Win32.RegistryHive]::LocalMachine;
	$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($type, $ComputerName);
	$regKey= $reg.OpenSubKey("SOFTWARE\\",$True);
	$regkey.CreateSubKey("CompanyName");
	$regKey= $reg.OpenSubKey("SOFTWARE\\CompanyName",$True);
	$regkey.CreateSubKey("Warranty");
	$regKey= $reg.OpenSubKey("SOFTWARE\\CompanyName\Warranty",$True);
	$regKey.Setvalue('End Date', $warranty[0], 'String');
	$regKey.Setvalue('Manufacturer', $manufacturer, 'String');
	$regKey.Setvalue('Model', $model, 'String');
	$regKey.Setvalue('Serial Number', $serialnumber, 'String');
	
	}
	
} catch {
	Write-Warning "Trouble accessing, RPC might be unavailable";
	$ComputerName | out-file $file -Append -NoClobber;
}
}
else {
write-host $ComputerName " Offline";
$ComputerName | out-file $file -Append -NoClobber;
exit;
}
