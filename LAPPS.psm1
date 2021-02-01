Import-Module -Name $PSScriptRoot/functions/misc.ps1
Import-Module -Name $PSScriptRoot/functions/Key.ps1
Import-Module -Name $PSScriptRoot/functions/Link.ps1


$exports = @(
    'New-KeyDatabase',
    'Register-Approver',
    'Unregister-Approver',
    'Edit-ApproverStatus',
    'Get-KeyRecord',
    'Get-AllKeyRecord',
    'Split-KeyRecord',
    'New-LinkDatabase',
    'New-SaltedHash',
    'New-Signature',
    'New-ConfirmResult',
    'Confirm-Record',
    'Approve-File',
    'Get-LinkRecord',
    'Get-LastLinkRecord',
    'Get-AllLinkRecord',
    'Split-LinkRecord'
)

Export-ModuleMember -Function $exports
