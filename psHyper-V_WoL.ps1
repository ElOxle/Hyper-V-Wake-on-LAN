# --------------------------------------------------------------------------------------------------------
# Hyper-V Wake-on-LAN Listener
# (c) 2016 - Daniel Oxley - https://deploymentpros.wordpress.com/2016/11/28/wake-on-lan-for-hyper-v-guests
#
# Please maintain this header and provide credit to author.
#
# You are free to use this code for non-commercial reasons.  No support is provided
# whatsoever and you use it at your own risk.  No responisibility by the author is
# accepted.
#
# History:
# v0.1 - Daniel Oxley - Initial version
# V0.2 - Daniel Oxley - Tidy up messages in console window and added Time/Date information
#
# Usage:
# psHyper-V_WoL.ps1 [UDP port number] [Loop until end]
# ex: psHyper-V_WoL.ps1 7 $TRUE
# ex: psHyper-V_WoL.ps1 7 $FALSE
#
# Error codes:
#  0 - execution successful
#  1 - incorrect command line specified
# --------------------------------------------------------------------------------------------------------

function Receive-UDPMessage
{
    [CmdletBinding(DefaultParameterSetName='Relevance', SupportsShouldProcess=$False)]

    Param([parameter(Mandatory=$True,Position=0, HelpMessage='The UDP port to listen on')]
    [Int]$Port,
    [parameter(Mandatory=$True,Position=1, HelpMessage='Boolean value to specify whether the code should continue listening after processing 1 message or quit')]
    [bool]$Loop
    )

    Try
    {
        $endpoint = new-object System.Net.IPEndPoint ([IPAddress]::Any,$port)
        $udpclient = new-Object System.Net.Sockets.UdpClient $port

        Do
        {
            Write-Host
            Write-Host (Get-Date).ToString("yyyy/MM/dd HH:MM:ss") "Waiting for message on UDP port $Port..."
            Write-Host ""
        
            $content = $udpclient.Receive([ref]$endpoint)
            $strContent = $([Text.Encoding]::ASCII.GetString($content))

            Write-Host (Get-Date).ToString("yyyy/MM/dd HH:MM:ss") "Message received from: $($endpoint.address.toString()):$($endpoint.Port)"

            $tmpVal = ""
            $receivedMAC = ""

            For($i = 6; $i -lt 12; $i++)
            {
                $tmpVal = [convert]::tostring($content[$i],16)
                If ($tmpVal.Length -lt 2){$tmpVal = "0" + $tmpVal}
                $receivedMAC = $receivedMAC + $tmpVal.ToUpper()
            }

            $tmpMAC = FormatMAC -MACToFormat $receivedMAC
            Write-Host (Get-Date).ToString("yyyy/MM/dd HH:MM:ss") "WoL MAC address received: $($tmpMAC)"
            $tmpMAC = ""

            Write-Host (Get-Date).ToString("yyyy/MM/dd HH:MM:ss") "Searching MAC addresses on Hyper-V host $myFQDN"

            $boolFound = $False

            ForEach ($strMAC in $arrMACs)
            {
                If ($strMAC.Trim() -eq $receivedMAC) #$strContent.Trim())
                {
                    $tmpMAC = FormatMAC -MACToFormat $strMAC
                    Write-Host (Get-Date).ToString("yyyy/MM/dd HH:MM:ss") "Matched MAC address: $($tmpMAC)"
                    $tmpMAC = ""

                    StartVM -MacToStart $strMAC
                    $boolFound = $True
                }
                Else
                {
                    # No match, keep going
                }
            }

            If ($boolFound -eq $false){Write-Host (Get-Date).ToString("yyyy/MM/dd HH:MM:ss") "No VM found on host that matches the MAC address received."}

            Write-Host
            Write-Host "-------------------------------------------------------------------------------"
        }
    While($Loop)
    }
    Catch [system.exception]
    {
        throw $error[0]
    }
    Finally
    {
        Write-Host (Get-Date).ToString("yyyy/MM/dd HH:MM:ss") "Closing connection."
        $udpclient.Close()
    }
}

function StartVM
{
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$true)]
    [string]$MacToStart
    )

    ForEach ($startVM in $objVMs)
    {
        If ($MacToStart -eq $startVM.NetworkAdapters.Item(0).MacAddress.Trim())
        {
            Write-Host "Starting VM: $($startVM.Name)"
            Start-VM -Name $startVM.Name
        }
    }
}

function FormatMAC
{
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$true)]
    [string]$MACToFormat
    )

    $MACToFormat = $MACToFormat.Insert(2, ":")
    $MACToFormat = $MACToFormat.Insert(5, ":")
    $MACToFormat = $MACToFormat.Insert(8, ":")
    $MACToFormat = $MACToFormat.Insert(11, ":")
    $MACToFormat = $MACToFormat.Insert(14, ":")

    Return $MACToFormat

}

If ($args.Count -ne 2)
{
    Write-Host
    Write-Host "ERROR: You must specify the correct command line!"
    Write-Host
    Write-Host "Usage:"
    Write-Host "       psReceiveMagicPacket.ps1 (UDP port number) (Loop until end)"
    Write-Host "       ex: psWindowsUpdate.ps1 7 $([char]36)TRUE"
    Write-Host

    Exit(1)
}


cls

$myFQDN = (Get-WmiObject win32_ComputerSystem).DNSHostName + "." + (Get-WmiObject win32_ComputerSystem).Domain

$objVMs = Get-VM

If ($objVMs.Count -eq 0)
{
    Write-Host "ERROR: No virtual machines found on host!"
}
Else
{
    Write-Host
    Write-Host "The following Virtual Machines have been found on Hyper-V host $($myFQDN):"
    Write-Host
    Write-Host "MAC Address        ¦ VM Name"
    Write-Host "-------------------¦-------------------"

    $arrMACs = @()
    
    ForEach ($VM in $objVMs)
    {
        $arrMACs += $VM.NetworkAdapters.Item(0).MacAddress
        $tmpMAC = FormatMAC -MACToFormat $VM.NetworkAdapters.Item(0).MacAddress
        Write-Host "$($tmpMAC)  ¦ $($VM.Name)"
        $tmpMAC = ""
    }

    Write-Host "-------------------¦-------------------"
    Write-Host
    Write-Host
    Write-Host "*******************************************************************************"

    $intPort = $args[0]
    Receive-UDPMessage -Port $intPort -Loop $args[1]

    Exit(0)
}