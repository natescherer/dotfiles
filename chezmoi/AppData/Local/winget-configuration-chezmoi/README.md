# REAME

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
