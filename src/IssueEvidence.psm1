Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'IssueEvidence.Contract.ps1')
. (Join-Path $PSScriptRoot 'IssueEvidence.Privacy.ps1')
. (Join-Path $PSScriptRoot 'IssueEvidence.Source.ps1')
. (Join-Path $PSScriptRoot 'IssueEvidence.Model.ps1')
. (Join-Path $PSScriptRoot 'IssueEvidence.Serialization.ps1')

function Invoke-IssueBoundary([scriptblock] $Work) {
    try {
        $ErrorActionPreference='Stop'
        $value=& $Work
        return [pscustomobject]@{success=$true;code=$null;message=$null;value=$value}
    } catch {
        # No source object, exception, target object, stack, path or ErrorRecord escapes.
        $code='EXPORT_NORMALIZATION_FAILED'
        if ($script:IssueFailures.ContainsKey($_.Exception.Message)) { $code=$_.Exception.Message }
        return [pscustomobject]@{success=$false;code=$code;message=$script:IssueFailures[$code];value=$null}
    }
}
function ConvertTo-IssueEvidenceModel {
    param([AllowNull()] [object] $Source)
    Invoke-IssueBoundary { New-IssuePublicModel $Source }
}
function ConvertTo-IssueEvidenceJson {
    param([AllowNull()] [object] $Model)
    Invoke-IssueBoundary { Write-IssueJson (Copy-IssuePublicModel $Model) }
}
function ConvertTo-IssueEvidenceMarkdown {
    param([AllowNull()] [object] $Model)
    Invoke-IssueBoundary { Write-IssueMarkdown (Copy-IssuePublicModel $Model) }
}
function Test-IssueEvidencePrivacy {
    param([AllowNull()] [object] $Model)
    Invoke-IssueBoundary { $copy=Copy-IssuePublicModel $Model; $null=Write-IssueJson $copy; $true }
}
function ConvertTo-IssueEvidencePackage {
    param([AllowNull()] [object] $Source, [AllowNull()] [object] $Model)
    Invoke-IssueBoundary {
        Assert-Issue (($null -eq $Source) -ne ($null -eq $Model)) 'EXPORT_SOURCE_INCOMPLETE'
        $safe=if ($null -ne $Source) { New-IssuePublicModel $Source } else { Copy-IssuePublicModel $Model }
        $json=Write-IssueJson $safe
        $markdown=Write-IssueMarkdown $safe
        $encoding=[Text.UTF8Encoding]::new($false,$true)
        # Publish one result only after BOTH serializers and privacy gates succeed.
        [pscustomobject]@{model=$safe;json=$json;markdown=$markdown;json_bytes=$encoding.GetBytes($json);markdown_bytes=$encoding.GetBytes($markdown)}
    }
}
Export-ModuleMember -Function ConvertTo-IssueEvidenceModel,ConvertTo-IssueEvidenceJson,ConvertTo-IssueEvidenceMarkdown,Test-IssueEvidencePrivacy,ConvertTo-IssueEvidencePackage
