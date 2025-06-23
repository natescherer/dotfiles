#! /bin/zsh

# The below ensures that this file will change when the hashed files change, triggering this script to execute
{{ range .macos_defaults_apps -}}
## {{ . }} hash: {{ include . | sha256sum }}
{{ end -}}

domains=({{ .macos_defaults_apps | quoteList | join " " }})

for domain in "${domains[@]}"; do
    defaults import $domain ~/.config/defaults/$domain.plist
    echo "\033[1;34mImporting ~/.config/defaults/$domain.plist via 'defaults import'...\033[0m"
done
