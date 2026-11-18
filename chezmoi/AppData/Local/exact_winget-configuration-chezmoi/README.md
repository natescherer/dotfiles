# README

Each file is named using a specific naming pattern:

> #.PURPOSE[-TAG].METADATA.winget[.tmpl]

\# = A number designed to sort config execution into specific steps. Will always be used, because you're always going to have a "requirements" step that installs DSC modules
PURPOSE = an alphanumeric description of what applying the file changes on the system
TAG = [OPTIONAL] an optional, alphanumeric identifier for when there is more than one file that shares PURPOSE and METADATA
METADATA = One or more of these letters, sorted alphabetically, to indicate info about the file.
    - **a**: All Machines (mutually-exclusive with any other letters)
    - **e**: Elevation Required, only for machines where account has admin rights (or the ability to elevate with another account)
    - **p**: Personal Machines Only
.winget = File extension [recommended by Microsoft](https://learn.microsoft.com/en-us/windows/package-manager/configuration/create-v3)
.tmpl = [OPTIONAL] When needed, to allow templating the file using chezmoi

Within a file, either every resource sets `securityContext: elevated` or none does. The apply
script runs each file that has any elevated resource from a single elevated process, so an
unelevated resource in such a file would also run elevated. Put unelevated resources in a
separate file without the **e** letter.

Call DISM (optional features, capabilities, Features on Demand) only through
`Microsoft.DSC.Transitional/WindowsPowerShellScript` or `dism.exe`. DISM fails inside MSIX
packages, which rules out DSC's own DISM resources under the Appx-packaged DSC and DISM cmdlets
under PowerShell 7.7+ (see <https://github.com/PowerShell/PowerShell/issues/13866>). The apply
script refuses to run a file that does either.
