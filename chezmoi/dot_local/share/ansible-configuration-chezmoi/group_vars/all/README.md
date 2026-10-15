# README

Each file is named using a specific naming pattern:

> PURPOSE.METADATA.yml[.tmpl]

PURPOSE = an alphanumeric description of what variables the file defines
METADATA = One of these letters to indicate info about the file.
    - **a**: All Machines
    - **p**: Personal Machines Only (excluded on non-personal machines via the `*.p.yml` glob in `.chezmoiignore.tmpl`)
.yml = File extension
.tmpl = [OPTIONAL] When needed, to allow templating the file using chezmoi
