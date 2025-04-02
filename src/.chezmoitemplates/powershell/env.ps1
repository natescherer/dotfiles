# Set up standard user directories
$env:XDG_CONFIG_HOME = $(Join-Path $HOME ".config")
$env:XDG_DATA_HOME = $(Join-Path $HOME ".local" "share")
$env:XDG_CACHE_HOME = $(Join-Path $HOME ".cache")

# Remap az data location from root of ~
$env:AZURE_CONFIG_DIR = $(Join-Path $env:XDG_DATA_HOME "azure")

# Remap python data from root of ~
$env:PYTHON_HISTORY = $(Join-Path $env:XDG_STATE_HOME "python_history")
$env:PYTHONPYCACHEPREFIX = $(Join-Path $env:XDG_CACHE_HOME "python")
$env:PYTHONUSERBASE = $(Join-Path $env:XDG_DATA_HOME "python")

# Remap docker data from root of ~
$env:DOCKER_CONFIG = $(Join-Path $env:XDG_CONFIG_HOME "docker")

# Remap npm data from root of ~
$env:NPM_CONFIG_USERCONFIG = $(Join-Path $XDG_CONFIG_HOME "npm" "npmrc")
