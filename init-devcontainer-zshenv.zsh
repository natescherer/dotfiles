# Placeholder ~/.zshenv from init-devcontainer.sh, which copies it before
# installing anything. chezmoi replaces it with the real ~/.zshenv, so only
# shells that start while the dotfiles are still installing read it.
if [[ -o interactive ]]; then
    print 'Dotfiles are still installing; this shell does not have them.'

    # Reports once, at the first prompt after init-devcontainer.sh exits
    _dotfiles_check() {
        case $(cat ~/.local/state/dotfiles/devcontainer-status 2>/dev/null) in
            ok) print 'Dotfiles installed. Run exec zsh to load them.' ;;
            failed) print 'Dotfiles failed to install. See ~/.local/state/dotfiles/init-devcontainer.log' ;;
            *) return ;;
        esac
        add-zsh-hook -d precmd _dotfiles_check
    }

    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _dotfiles_check
fi
