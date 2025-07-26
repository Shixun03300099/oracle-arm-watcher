# oracle-arm-watcher.ps1

$webhookUrl = "https://discord.com/api/webhooks/1398443190532440164/vBGiNwXcH9ChuGvSkn86CnCLXIR6r3Ehzsr0XYtafUzkMvm-ohRSvdXZYi6JaSOu86Pu"  # Replace with your webhook URL

function Send-DiscordMessage($message) {
    $payload = @{
        content = $message
    } | ConvertTo-Json
    Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType 'application/json' -Body $payload
}

Write-Output "Starting Oracle Cloud ARM capacity monitor..."

# Read your SSH public key content (make sure your public key file path is correct)
$publicKey = Get-Content -Raw "$env:USERPROFILE\.ssh\oci_arm_key.pub" | Out-String
$publicKey = $publicKey.Trim()  # Remove trailing newline

while ($true) {
    try {
        Write-Output "Checking for available capacity..."
        $result = & oci compute shape list --compartment-id ocid1.tenancy.oc1..aaaaaaaa6tyvs2fvfoqifagcvloamgb6kwtalmouwaxho2mwxp6ziaids6ha --output json | ConvertFrom-Json

        $available = $false
        foreach ($shape in $result.data) {
            if ($shape.shape -eq "VM.Standard.A1.Flex" -and $shape.ocpusMax -ge 4 -and $shape.memoryInGBsMax -ge 24) {
                $available = $true
                break
            }
        }

        if ($available) {
            Send-DiscordMessage "Capacity found! Launching instance..."

            $metadataJson = @{ ssh_authorized_keys = $publicKey } | ConvertTo-Json -Compress

            $launchResult = & oci compute instance launch --availability-domain "AD-1" `
                --compartment-id ocid1.tenancy.oc1..aaaaaaaa6tyvs2fvfoqifagcvloamgb6kwtalmouwaxho2mwxp6ziaids6ha `
                --shape "VM.Standard.A1.Flex" `
                --shape-config '{"ocpus": 4, "memoryInGBs": 24}' `
                --subnet-id ocid1.vcn.oc1.us-chicago-1.amaaaaaa4e7rjnqa7b5gsfqcadt6cwdrba67mblncqceetexo7ba4wv62rkq `
                --assign-public-ip true `
                --display-name "AutoARMInstance" `
                --image-id ocid1.image.oc1.us-chicago-1.aaaaaaaahavk6zg2lzsgscm2ru6yfqwefp5x4jm4wfwnm44gguefxzb5ss5a `
                --metadata $metadataJson

            Send-DiscordMessage "Instance launched!"
            break
        } else {
            Write-Output "No capacity available. Will retry in 5 minutes."
            Send-DiscordMessage "No capacity available. Retrying in 5 minutes..."
        }
    } catch {
        Write-Output "Error: $_"
        Send-DiscordMessage "Error during check: $_"
    }

    Start-Sleep -Seconds 300
}
