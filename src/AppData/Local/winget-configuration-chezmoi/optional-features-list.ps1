# Single source of truth for optional-features.configuration.winget's WindowsOptionalFeatures resource.
# Dot-sourced identically by that resource's getScript/testScript/setScript, which run as three
# independent script invocations with no shared state, so this can't just be a variable defined
# once inside that file -- this is the plain-PowerShell alternative to templating the array.
@('Containers', 'NetFx3', 'HypervisorPlatform', 'Containers-DisposableClientVM', 'SimpleTCP', 'TelnetClient', 'TFTP')
